#!/bin/sh
# Тесты балансировки по скорости.
#
# Аппаратная часть (bo, замер через probe+adrules) доказана на живом роутере,
# здесь проверяется sh-логика, которая от железа не зависит: разбор нод из
# конфига, разбор вывода bi, чтение/запись настроек и решение гистерезиса.
# xray и curl заглушены shell-функциями, xray-конфиги — фикстуры во временном
# каталоге. Нужен jq (alpine).

italic=""; reset=""; red=""; green=""; yellow=""; light_blue=""

WORK=/tmp/sb_test
rm -rf "$WORK"; mkdir -p "$WORK"

# --- переменные, которые обычно ставит 01_info_variable.sh ---
xray_conf_dir="$WORK/configs"; mkdir -p "$xray_conf_dir"
tmp_dir="$WORK"
xkeen_config="$WORK/xkeen.json"
sb_api_addr="127.0.0.1:10085"
sb_probe_addr="127.0.0.1:10808"
sb_probe_intag="probe"
sb_rule_tag="xkeen-sb-probe"
sb_rule_tmp="$WORK/sb_rule.json"
sb_log_file="$WORK/sb.log"
sb_routing_file="$xray_conf_dir/05_routing.json"
sb_outbounds_file="$xray_conf_dir/04_outbounds.json"

strip_json_comments() {
    sed -e ':a; s:/\*[^*]*\*[^/]*\*/::g; ta' \
        -e 's/^[[:space:]]*\/\/.*$//' \
        -e 's/[[:space:]]\{1,\}\/\/.*$//' "$@"
}

# speed_balancer_settings копируется сюда в упрощённом виде — тот же разбор,
# что в 01_info_variable.sh, но без прочего содержимого файла переменных.
speed_balancer_settings() {
    sb_enabled="false"; sb_log_enabled="true"; sb_interval="15"; sb_hysteresis="25"
    sb_balancer="balancer"; sb_maxtime="8"
    sb_test_url="https://speed.cloudflare.com/__down?bytes=50000000"
    if [ -f "$xkeen_config" ] && command -v jq >/dev/null 2>&1; then
        json_clean=$(strip_json_comments "$xkeen_config")
        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.speed_balancer.enabled // empty' 2>/dev/null)
        [ "$v" = "true" ] && sb_enabled="true"
        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.speed_balancer.log' 2>/dev/null)
        [ "$v" = "false" ] && sb_log_enabled="false"
        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.speed_balancer.interval // empty' 2>/dev/null)
        [ -n "$v" ] && [ "$v" -gt 0 ] 2>/dev/null && sb_interval="$v"
        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.speed_balancer.hysteresis // empty' 2>/dev/null)
        [ -n "$v" ] && [ "$v" -ge 0 ] 2>/dev/null && sb_hysteresis="$v"
        v=$(printf '%s' "$json_clean" | jq -r '.xkeen.speed_balancer.balancer // empty' 2>/dev/null)
        [ -n "$v" ] && sb_balancer="$v"
    fi
}

. /repo/scripts/_xkeen/04_tools/08_tools_balancer/01_balancer_core.sh
. /repo/scripts/_xkeen/04_tools/08_tools_balancer/02_balancer_control.sh

# --- заглушки xray и curl ------------------------------------------------
# STUB_CURRENT — что балансировщик выбирает сейчас; STUB_SPEED_<node> в КБ*1024
# задаёт «скорость» ноды (байт за 1с). STUB_BO — куда записан последний bo.
STUB_CURRENT="sub-a"; STUB_BO=""; STUB_OVERRIDE=""

xray() {
    # $1=api
    case "$2" in
        lsrules) echo '{"rules":[]}'; return 0 ;;
        # Override печатается, только если STUB_OVERRIDE задан (как на живом bi:
        # пустая секция = override не выставлен). Selects всегда = STUB_CURRENT.
        # Печатаем по строкам, а не через $(...) — подстановка срезала бы \n и
        # склеила строку Override со строкой "Selects:".
        bi)  printf '  - Selecting Override:\n'
             [ -n "$STUB_OVERRIDE" ] && printf '    1   %s          \n' "$STUB_OVERRIDE"
             printf '  - Selects:\n    1   %s          \n' "$STUB_CURRENT"
             return 0 ;;
        adrules) return 0 ;;
        rmrules) return 0 ;;
        bo)
            # xray api bo -s ADDR -b BAL (NODE | -r)
            shift 2
            _node=""; while [ $# -gt 0 ]; do case "$1" in -r) _node="-r" ;; -s|-b) shift ;; *) _node="$1" ;; esac; shift; done
            STUB_BO="$_node"; [ "$_node" != "-r" ] && STUB_CURRENT="$_node"; return 0 ;;
        *) return 0 ;;
    esac
}

curl() {
    # Узнаём ноду из правила, записанного sb_measure_node, и отдаём её скорость.
    # STUB_RAW, если задан, печатается как есть (для проверки разбора -w).
    [ -n "$STUB_RAW" ] && { printf '%s' "$STUB_RAW"; return 1; }
    _n=$(jq -r '.routing.rules[0].outboundTag' "$sb_rule_tmp" 2>/dev/null)
    _bytes=$(eval "printf '%s' \"\${STUB_SPEED_$(echo "$_n" | tr '-' '_')}\"")
    [ -n "$_bytes" ] || _bytes=0
    # формат -w: size_download time_total http_code (без завершающего пробела)
    if [ "$_bytes" = "0" ]; then printf '0 0 000'; else printf '%s 1 200' "$_bytes"; fi
}

pass=0; fail=0
check() {
    if [ "$2" = "$3" ]; then printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1)); fi
}

# --- фикстуры конфига ---
cat > "$xray_conf_dir/05_routing.json" <<'EOF'
{ "routing": { "balancers": [
  { "tag": "balancer", "selector": ["sub-"] },
  { "tag": "balancer-us", "selector": ["sub-us"] }
], "rules": [] } }
EOF
cat > "$xray_conf_dir/04_outbounds.json" <<'EOF'
{ "outbounds": [
  { "tag": "sub-a" }, { "tag": "sub-b" }, { "tag": "sub-us1" },
  { "tag": "direct" }, { "tag": "block" }
] }
EOF

# === настройки: дефолты и переопределение ===
speed_balancer_settings
check "дефолт: выключено" "$sb_enabled" "false"
check "дефолт: интервал 15" "$sb_interval" "15"
check "дефолт: гистерезис 25" "$sb_hysteresis" "25"

printf '{"xkeen":{"speed_balancer":{"enabled":true,"interval":5,"hysteresis":40,"balancer":"balancer-us"}}}' > "$xkeen_config"
speed_balancer_settings
check "чтение: включено" "$sb_enabled" "true"
check "чтение: интервал" "$sb_interval" "5"
check "чтение: гистерезис" "$sb_hysteresis" "40"
check "чтение: балансировщик" "$sb_balancer" "balancer-us"

# === запись настройки sb_write_setting ===
rm -f "$xkeen_config"
sb_write_setting enabled true
check "запись создаёт enabled=true" "$(strip_json_comments "$xkeen_config" | jq -r '.xkeen.speed_balancer.enabled')" "true"
sb_write_setting enabled false
check "запись меняет на false" "$(strip_json_comments "$xkeen_config" | jq -r '.xkeen.speed_balancer.enabled')" "false"
sb_write_setting interval 7
check "запись числа не в кавычках" "$(strip_json_comments "$xkeen_config" | jq -r '.xkeen.speed_balancer.interval')" "7"
check "прочие ключи не затёрты" "$(strip_json_comments "$xkeen_config" | jq -r '.xkeen.speed_balancer.enabled')" "false"

# === разбор нод балансировщика по selector ===
sb_balancer="balancer"
sb_node_list
check "ноды balancer по подстроке sub-" "$sb_nodes" "sub-a sub-b sub-us1"
sb_balancer="balancer-us"
sb_node_list
check "ноды balancer-us (sub-us)" "$sb_nodes" "sub-us1"
sb_balancer="нет-такого"
sb_node_list; rc=$?
check "неизвестный балансировщик -> код 1" "$rc" "1"

# === кастомные имена файлов (routing_file / outbounds_file) ===
# Ядро читает конфиг через $sb_routing_file/$sb_outbounds_file, а не по хардкоду —
# при кастомных именах ноды всё равно должны разбираться.
cat > "$xray_conf_dir/routing_custom.json" <<'EOF'
{ "routing": { "balancers": [
  { "tag": "balancer", "selector": ["node-"] }
], "rules": [] } }
EOF
cat > "$xray_conf_dir/outbounds_custom.json" <<'EOF'
{ "outbounds": [ { "tag": "node-1" }, { "tag": "node-2" }, { "tag": "direct" } ] }
EOF
sb_routing_file="$xray_conf_dir/routing_custom.json"
sb_outbounds_file="$xray_conf_dir/outbounds_custom.json"
sb_balancer="balancer"
sb_node_list
check "кастомные имена файлов: ноды по node-" "$sb_nodes" "node-1 node-2"
# вернуть дефолтные пути — дальше sb_tick внутри снова зовёт sb_node_list
sb_routing_file="$xray_conf_dir/05_routing.json"
sb_outbounds_file="$xray_conf_dir/04_outbounds.json"

# === разбор текущей ноды из bi (Override приоритетнее Selects) ===
sb_balancer="balancer"; STUB_CURRENT="sub-b"; STUB_OVERRIDE=""
check "sb_current_target: без override берёт Selects" "$(sb_current_target)" "sub-b"
STUB_OVERRIDE="sub-z"
check "sb_current_target: override приоритетнее Selects" "$(sb_current_target)" "sub-z"
STUB_OVERRIDE=""

# === замер одной ноды (возвращает "КБ/с код") ===
STUB_SPEED_sub_a=$((2048*1024))   # 2048 КБ/с
printf '{"routing":{"rules":[{"ruleTag":"x","type":"field","inboundTag":["probe"],"outboundTag":"sub-a"}]}}' > "$sb_rule_tmp"
check "sb_measure_node считает КБ/с и код" "$(sb_measure_node sub-a)" "2048 200"
STUB_SPEED_sub_a=0
check "нулевой ответ -> 0 и код" "$(sb_measure_node sub-a)" "0 000"

# таймаут: curl вышел с ошибкой, но -w уже отдал частичный размер и код 200 —
# это валидный замер медленной ноды, а не провал (регрессия на слипание ||echo)
STUB_RAW="4194304 8 200"
check "таймаут с частичной закачкой -> скорость, не 0" "$(sb_measure_node sub-a)" "512 200"
STUB_RAW="0 0 000"
check "полный отказ -> 0 000" "$(sb_measure_node sub-a)" "0 000"
STUB_RAW=""

# === гистерезис в sb_tick ===
# порог задаём явно, чтобы тест не зависел от ранее прочитанных настроек
sb_balancer="balancer"; sb_hysteresis=25; sb_maxtime=8
# текущая sub-a=1000, кандидат sub-b=1200 (+20%) — ниже порога 25%, не менять
STUB_CURRENT="sub-a"; STUB_BO=""
STUB_SPEED_sub_a=$((1000*1024)); STUB_SPEED_sub_b=$((1200*1024)); STUB_SPEED_sub_us1=0
sb_tick >/dev/null 2>&1
check "гистерезис: +20% не переключает" "$STUB_BO" ""
check "гистерезис: текущая осталась" "$STUB_CURRENT" "sub-a"

# кандидат sub-b=1300 (+30%) — выше порога 25%, переключить
STUB_CURRENT="sub-a"; STUB_BO=""
STUB_SPEED_sub_a=$((1000*1024)); STUB_SPEED_sub_b=$((1300*1024))
sb_tick >/dev/null 2>&1
check "гистерезис: +30% переключает" "$STUB_BO" "sub-b"

# текущая недоступна (0), любой ненулевой кандидат проходит
STUB_CURRENT="sub-a"; STUB_BO=""
STUB_SPEED_sub_a=0; STUB_SPEED_sub_b=$((500*1024))
sb_tick >/dev/null 2>&1
check "мёртвая текущая -> переключение на живую" "$STUB_BO" "sub-b"

# все ноды мертвы — выбор не трогаем
STUB_CURRENT="sub-a"; STUB_BO=""
STUB_SPEED_sub_a=0; STUB_SPEED_sub_b=0; STUB_SPEED_sub_us1=0
sb_tick >/dev/null 2>&1
check "все мертвы -> bo не вызван" "$STUB_BO" ""

# === лог: параметр .speed_balancer.log (issue #103) ===
sb_log_file="$WORK/sblog.log"; rm -f "$sb_log_file"
sb_log_enabled="true"; sb_log "строка при включённом логе"
check "лог пишется при sb_log_enabled=true" "$([ -s "$sb_log_file" ] && echo yes || echo no)" "yes"

rm -f "$sb_log_file"
sb_log_enabled="false"; sb_log "строка при выключенном логе"
check "лог молчит при sb_log_enabled=false" "$([ -e "$sb_log_file" ] && echo yes || echo no)" "no"

# сквозь настройки: .log:false -> sb_log_enabled=false
printf '{"xkeen":{"speed_balancer":{"log":false}}}' > "$xkeen_config"
speed_balancer_settings
check "settings: .log false -> sb_log_enabled false" "$sb_log_enabled" "false"
printf '{"xkeen":{"speed_balancer":{}}}' > "$xkeen_config"
speed_balancer_settings
check "settings: без .log -> sb_log_enabled true (дефолт)" "$sb_log_enabled" "true"

# === sb_write_setting: обновляем ТОЛЬКО блок балансера, остальное (и комментарии) целы ===
# rjq — читать ключ через strip (в конфиге есть комментарии)
rjq() { strip_json_comments "$xkeen_config" | jq -r "$1" 2>/dev/null; }

# 1) вставка, когда блока ещё нет: policy и комментарий сохранены
cat > "$xkeen_config" <<'JSON'
{
  "xkeen": {
    // моя политика доступа
    "policy": [ { "name": "XKeen", "port": "80,443" } ]
  }
}
JSON
rm -f "$xkeen_config.bak"
sb_write_setting enabled true >/dev/null 2>&1; check "insert: rc=0" "$?" "0"
check "insert: enabled записан"          "$(rjq '.xkeen.speed_balancer.enabled')" "true"
check "insert: policy цела"              "$(rjq '.xkeen.policy[0].name')" "XKeen"
check "insert: комментарий сохранён"     "$(grep -c 'моя политика доступа' "$xkeen_config")" "1"
check "insert: бэкап создан"             "$([ -f "$xkeen_config.bak" ] && echo yes || echo no)" "yes"
check "insert: результат валиден"        "$(strip_json_comments "$xkeen_config" | jq -e . >/dev/null 2>&1 && echo ok || echo bad)" "ok"

# 2) обновление блока: чужие sb-параметры (значения) целы, комментарий снаружи цел
cat > "$xkeen_config" <<'JSON'
{
  "xkeen": {
    "policy": [ { "name": "XKeen" } ],
    "speed_balancer": {
      "enabled": false,
      "interval": 20,
      "log": false
    },
    "gh_proxy": "example.com"
  }
}
JSON
sb_write_setting enabled true >/dev/null 2>&1; check "update: rc=0" "$?" "0"
check "update: enabled -> true"          "$(rjq '.xkeen.speed_balancer.enabled')" "true"
check "update: чужой interval сохранён"  "$(rjq '.xkeen.speed_balancer.interval')" "20"
check "update: чужой log сохранён"       "$(rjq '.xkeen.speed_balancer.log')" "false"
check "update: соседний gh_proxy цел"    "$(rjq '.xkeen.gh_proxy')" "example.com"
check "update: policy цела"              "$(rjq '.xkeen.policy[0].name')" "XKeen"

# 3) фигурная скобка в чужом комментарии НЕ сбивает счёт скобок блока
cat > "$xkeen_config" <<'JSON'
{
  "xkeen": {
    // порты вида {80,443} и скобка }
    "policy": [ { "name": "XKeen" } ],
    "speed_balancer": { "enabled": false }
  }
}
JSON
sb_write_setting enabled true >/dev/null 2>&1; check "скобки-в-комменте: rc=0" "$?" "0"
check "скобки-в-комменте: enabled -> true" "$(rjq '.xkeen.speed_balancer.enabled')" "true"
check "скобки-в-комменте: комментарий цел" "$(grep -c '80,443' "$xkeen_config")" "1"

# 4) пустой .xkeen -> блок добавляется вставкой
printf '{"xkeen":{}}\n' > "$xkeen_config"
sb_write_setting enabled true >/dev/null 2>&1; check "пустой xkeen: rc=0" "$?" "0"
check "пустой xkeen: enabled записан"     "$(jq -r '.xkeen.speed_balancer.enabled' "$xkeen_config")" "true"

# 5) файл {} -> собирается jq-fallback
printf '{}\n' > "$xkeen_config"
sb_write_setting enabled true >/dev/null 2>&1; check "пустой {}: rc=0" "$?" "0"
check "пустой {}: enabled записан"        "$(jq -r '.xkeen.speed_balancer.enabled' "$xkeen_config")" "true"

# 6) структурно битый конфиг (policy без name): запись отклонена, файл не изменён
cat > "$xkeen_config" <<'JSON'
{
  "xkeen": { "policy": [ { "port": "80" } ] }
}
JSON
cp "$xkeen_config" "$WORK/orig_bad.json"
sb_write_setting enabled true >/dev/null 2>&1; check "битая policy: rc=1" "$?" "1"
check "битая policy: sb НЕ добавлен"      "$(rjq '.xkeen.speed_balancer.enabled // "нет"')" "нет"
check "битая policy: файл не изменён"     "$(cmp -s "$xkeen_config" "$WORK/orig_bad.json" && echo same || echo diff)" "same"

rm -rf "$WORK"
printf '\n=== пройдено: %s, провалено: %s ===\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
