#!/bin/sh
# Тесты балансировки по скорости.
#
# Аппаратная часть (bo, замер через probe+adrules) доказана на живом роутере,
# здесь проверяется sh-логика, которая от железа не зависит: разбор нод из
# конфига, разбор вывода bi, чтение/запись настроек и решение гистерезиса.
# Теги outbound'ов могут содержать пробелы ("proxy DE Frankfurt") и прочие
# спецсимволы — для них есть отдельные регрессионные проверки (секции
# «теги с пробелами»): списки нод идут по одному тегу на строку.
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
cron_dir="$WORK/cron"; cron_file="root"
install_dir="$WORK/sbin"

# strip_json_comments/jc_set_path/validate_xkeen_json_syntax/speed_balancer_settings
# берём из реального кода, а не копией: модуль целиком не подключить (на
# верхнем уровне он ходит curl'ом в RCI роутера), а копия разъезжается с
# оригиналом (так и вышло: рукописная копия speed_balancer_settings отстала от
# схемы .xkeen.xray.speed_balancer, введённой коммитом 2b7276d). Тот же приём,
# что в test_strip_json.sh. Все четыре функции живут в 01_info_common.sh,
# sb_write_setting (02_balancer_control.sh) зовёт jc_set_path/
# validate_xkeen_json_syntax, поэтому их тоже нужно сорсить.
eval "$(awk '/^strip_json_comments\(\) \{/,/^\}/' /repo/scripts/_xkeen/01_info/01_info_common.sh)"
eval "$(awk '/^jc_set_path\(\) \{/,/^\}/' /repo/scripts/_xkeen/01_info/01_info_common.sh)"
eval "$(awk '/^validate_xkeen_json_syntax\(\) \{/,/^\}/' /repo/scripts/_xkeen/01_info/01_info_common.sh)"
eval "$(awk '/^speed_balancer_settings\(\) \{/,/^\}/' /repo/scripts/_xkeen/01_info/01_info_common.sh)"

. /repo/scripts/_xkeen/04_tools/08_tools_balancer/01_balancer_core.sh
. /repo/scripts/_xkeen/04_tools/08_tools_balancer/02_balancer_control.sh

# --- заглушки xray, curl и pidof -----------------------------------------
# STUB_CURRENT — что балансировщик выбирает сейчас; STUB_SPEED_<node> в КБ*1024
# задаёт «скорость» ноды (байт за 1с). STUB_BO — куда записан последний bo.
# STUB_API_ALIVE — отвечает ли gRPC api; STUB_XRAY_RUNNING/STUB_MIHOMO_RUNNING —
# что видит pidof (какое ядро запущено).
STUB_CURRENT="sub-a"; STUB_BO=""; STUB_OVERRIDE=""; STUB_API_ALIVE="yes"
STUB_XRAY_RUNNING="yes"; STUB_MIHOMO_RUNNING="no"

# smart_clear живёт в диспетчере xkeen, модулю доступна как готовая функция.
smart_clear() { :; }

pidof() {
    case "$1" in
        xray)   [ "$STUB_XRAY_RUNNING" = "yes" ]   && { echo 111; return 0; } ;;
        mihomo) [ "$STUB_MIHOMO_RUNNING" = "yes" ] && { echo 222; return 0; } ;;
    esac
    return 1
}

xray() {
    # $1=api
    case "$2" in
        lsrules) [ "$STUB_API_ALIVE" = "yes" ] || return 1
                 echo '{"rules":[]}'; return 0 ;;
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
    # Правило копируется наружу: sb_measure_node удаляет его за собой, а вызов
    # идёт из субшелла — файл единственный способ проверить, что в нём было.
    cp "$sb_rule_tmp" "$WORK/last_rule.json" 2>/dev/null
    # STUB_RAW, если задан, печатается как есть (для проверки разбора -w).
    [ -n "$STUB_RAW" ] && { printf '%s' "$STUB_RAW"; return 1; }
    _n=$(jq -r '.routing.rules[0].outboundTag' "$sb_rule_tmp" 2>/dev/null)
    # Имя переменной строится из тега заменой всех не-буквенно-цифровых
    # символов на "_" (тег может содержать пробелы, '*', кавычки): "sub-a" ->
    # sub_a, "proxy DE Frankfurt" -> proxy_DE_Frankfurt. printf, а не echo —
    # иначе завершающий перевод строки тоже превратился бы в "_".
    _bytes=$(eval "printf '%s' \"\${STUB_SPEED_$(printf '%s' "$_n" | tr -c 'A-Za-z0-9' '_')}\"")
    [ -n "$_bytes" ] || _bytes=0
    # формат -w: size_download time_total http_code (без завершающего пробела)
    if [ "$_bytes" = "0" ]; then printf '0 0 000'; else printf '%s 1 200' "$_bytes"; fi
}

pass=0; fail=0; known=0
check() {
    if [ "$2" = "$3" ]; then printf 'OK   %s\n' "$1"; pass=$((pass+1))
    else printf 'FAIL %s\n       ожидалось [%s]\n       получено  [%s]\n' "$1" "$3" "$2"; fail=$((fail+1)); fi
}

# Исторический регрессионный сценарий jc_set_path теперь проверяется
# обычным утверждением и входит в pass/fail наравне с остальными.
# Расхождение записанного значения больше не допускается как известный
# дефект и приводит к ненулевому коду завершения.
check_known() {
    check "$@"
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
# sb_enabled/sb_interval присваиваются внутри speed_balancer_settings, которая
# теперь берётся eval'ом awk-извлечения (см. выше) — shellcheck не видит
# присваивания внутри eval'нутого текста. sb_hysteresis и другие sb_* этому не
# подвержены, т.к. попутно присваиваются литералом где-то ещё в файле.
# shellcheck disable=SC2154
check "дефолт: выключено" "$sb_enabled" "false"
# shellcheck disable=SC2154
check "дефолт: интервал 15" "$sb_interval" "15"
check "дефолт: гистерезис 25" "$sb_hysteresis" "25"

printf '{"xkeen":{"xray":{"speed_balancer":{"enabled":true,"interval":5,"hysteresis":40,"balancer":"balancer-us"}}}}' > "$xkeen_config"
speed_balancer_settings
check "чтение: включено" "$sb_enabled" "true"
check "чтение: интервал" "$sb_interval" "5"
check "чтение: гистерезис" "$sb_hysteresis" "40"
check "чтение: балансировщик" "$sb_balancer" "balancer-us"

# === запись настройки sb_write_setting ===
rm -f "$xkeen_config"
sb_write_setting enabled true
check "запись создаёт enabled=true" "$(strip_json_comments "$xkeen_config" | jq -r '.xkeen.xray.speed_balancer.enabled')" "true"
sb_write_setting enabled false
check "запись меняет на false" "$(strip_json_comments "$xkeen_config" | jq -r '.xkeen.xray.speed_balancer.enabled')" "false"
sb_write_setting interval 7
check "запись числа не в кавычках" "$(strip_json_comments "$xkeen_config" | jq -r '.xkeen.xray.speed_balancer.interval')" "7"
check "прочие ключи не затёрты" "$(strip_json_comments "$xkeen_config" | jq -r '.xkeen.xray.speed_balancer.enabled')" "false"

# === разбор нод балансировщика по selector ===
sb_balancer="balancer"
sb_node_list
check "ноды balancer по префиксу sub-" "$sb_nodes" "$(printf '%s\n%s\n%s' sub-a sub-b sub-us1)"
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
check "кастомные имена файлов: ноды по node-" "$sb_nodes" "$(printf '%s\n%s' node-1 node-2)"
# вернуть дефолтные пути — дальше sb_tick внутри снова зовёт sb_node_list
sb_routing_file="$xray_conf_dir/05_routing.json"
sb_outbounds_file="$xray_conf_dir/04_outbounds.json"

# === теги с пробелами: разбор нод ===
# Регрессия: sb_nodes раньше была строкой через пробел, перебор шёл через
# `for x in $var`, и тег "proxy DE Frankfurt" рассыпался на три слова. Теперь
# один тег на строку, перебор через `read -r`. Фикстура включает тег с '*':
# через `for` он ещё и раскрылся бы в имена файлов текущего каталога.
cat > "$xray_conf_dir/routing_space.json" <<'EOF'
{ "routing": { "balancers": [
  { "tag": "balancer", "selector": ["proxy"] },
  { "tag": "balancer-de", "selector": ["proxy DE"] }
], "rules": [] } }
EOF
cat > "$xray_conf_dir/outbounds_space.json" <<'EOF'
{ "outbounds": [
  { "tag": "proxy DE Frankfurt" }, { "tag": "proxy US East 2" },
  { "tag": "proxy-NL" }, { "tag": "direct" }, { "tag": "proxy * all" },
  { "tag": "old proxy" }
] }
EOF
sb_routing_file="$xray_conf_dir/routing_space.json"
sb_outbounds_file="$xray_conf_dir/outbounds_space.json"

sb_balancer="balancer"
sb_node_list; rc=$?
check "теги с пробелами: sb_node_list rc=0" "$rc" "0"
check "теги с пробелами: ноды целиком, по одному на строку" "$sb_nodes" \
    "$(printf '%s\n%s\n%s\n%s' 'proxy DE Frankfurt' 'proxy US East 2' 'proxy-NL' 'proxy * all')"
check "теги с пробелами: число нод = 4 (не 10 слов)" "$(printf '%s\n' "$sb_nodes" | awk 'END { print NR }')" "4"
check "теги с пробелами: '*' не раскрыт в файлы" "$(printf '%s\n' "$sb_nodes" | grep -c -F 'proxy * all')" "1"
check "теги с пробелами: нет обрезанного 'proxy'" "$(printf '%s\n' "$sb_nodes" | grep -c -x 'proxy')" "0"
check "теги с пробелами: 'old proxy' (подстрока, не префикс) не взят" "$(printf '%s\n' "$sb_nodes" | grep -c -x 'old proxy')" "0"

# selector с пробелом: префикс "proxy DE" должен находить тег, а не
# распадаться на селекторы "proxy" и "DE"
sb_balancer="balancer-de"
sb_node_list
check "selector с пробелом: находит ровно свой тег" "$sb_nodes" "proxy DE Frankfurt"

# selector — ПРЕФИКС тега (как в Xray: ["a"] берёт "a" и "ab", но не "ba"), а не
# подстрока: иначе в замер и в bo попадали бы ноды, которых нет в пуле
# балансировщика. "DE Frankfurt" стоит в середине тега и не должен совпасть.
cat > "$xray_conf_dir/routing_prefix.json" <<'EOF'
{ "routing": { "balancers": [
  { "tag": "balancer", "selector": ["sub-"] },
  { "tag": "balancer-mid", "selector": ["DE Frankfurt"] }
], "rules": [] } }
EOF
cat > "$xray_conf_dir/outbounds_prefix.json" <<'EOF'
{ "outbounds": [
  { "tag": "sub-a" }, { "tag": "my-sub-b" }, { "tag": "xsub-c" },
  { "tag": "sub-d" }, { "tag": "proxy DE Frankfurt" }
] }
EOF
sb_routing_file="$xray_conf_dir/routing_prefix.json"
sb_outbounds_file="$xray_conf_dir/outbounds_prefix.json"
sb_balancer="balancer"
sb_node_list
check "префикс: берёт sub-a и sub-d, но не my-sub-b / xsub-c" "$sb_nodes" "$(printf '%s\n%s' sub-a sub-d)"
sb_balancer="balancer-mid"
sb_node_list; rc=$?
check "префикс: selector в середине тега не совпадает -> код 1" "$rc" "1"
check "префикс: selector в середине тега -> пустой список" "$sb_nodes" ""
sb_routing_file="$xray_conf_dir/routing_space.json"
sb_outbounds_file="$xray_conf_dir/outbounds_space.json"

sb_balancer="нет-такого"
sb_node_list; rc=$?
check "теги с пробелами: неизвестный балансировщик -> код 1" "$rc" "1"
# вернуть дефолтные пути
sb_routing_file="$xray_conf_dir/05_routing.json"
sb_outbounds_file="$xray_conf_dir/04_outbounds.json"

# === разбор текущей ноды из bi (Override приоритетнее Selects) ===
sb_balancer="balancer"; STUB_CURRENT="sub-b"; STUB_OVERRIDE=""
check "sb_current_target: без override берёт Selects" "$(sb_current_target)" "sub-b"
STUB_OVERRIDE="sub-z"
check "sb_current_target: override приоритетнее Selects" "$(sb_current_target)" "sub-z"
STUB_OVERRIDE=""
# тег с пробелами: берётся целиком, а не первое слово; хвостовые пробелы
# заглушки bi срезаются (на живом bi строка тоже добита пробелами)
STUB_CURRENT="proxy DE Frankfurt"; STUB_OVERRIDE=""
check "sb_current_target: Selects с пробелами целиком" "$(sb_current_target)" "proxy DE Frankfurt"
STUB_OVERRIDE="proxy US East 2"
check "sb_current_target: Override с пробелами целиком" "$(sb_current_target)" "proxy US East 2"
STUB_OVERRIDE=""; STUB_CURRENT="sub-a"

# === замер одной ноды (возвращает "КБ/с код") ===
STUB_SPEED_sub_a=$((2048*1024))   # 2048 КБ/с
printf '{"routing":{"rules":[{"ruleTag":"x","inboundTag":["probe"],"outboundTag":"sub-a"}]}}' > "$sb_rule_tmp"
check "sb_measure_node считает КБ/с и код" "$(sb_measure_node sub-a)" "2048 200"

# правило замера: без deprecated "type": "field" (xray-core v1.8.10+), но с тегами
check "правило замера: без type"          "$(jq -r '.routing.rules[0] | has("type")' "$WORK/last_rule.json")" "false"
check "правило замера: inbound->outbound" "$(jq -r '.routing.rules[0] | .inboundTag[0] + " -> " + .outboundTag' "$WORK/last_rule.json")" "probe -> sub-a"
check "правило замера: ruleTag"           "$(jq -r '.routing.rules[0].ruleTag' "$WORK/last_rule.json")" "$sb_rule_tag"

STUB_SPEED_sub_a=0
check "нулевой ответ -> 0 и код" "$(sb_measure_node sub-a)" "0 000"

# таймаут: curl вышел с ошибкой, но -w уже отдал частичный размер и код 200 —
# это валидный замер медленной ноды, а не провал (регрессия на слипание ||echo)
STUB_RAW="4194304 8 200"
check "таймаут с частичной закачкой -> скорость, не 0" "$(sb_measure_node sub-a)" "512 200"
STUB_RAW="0 0 000"
check "полный отказ -> 0 000" "$(sb_measure_node sub-a)" "0 000"
STUB_RAW=""

# теги с пробелами и спецсимволами: правило замера должно нести тег ТОЧНО
# (раньше JSON собирался printf'ом — кавычка или \ в теге ломали его)
STUB_SPEED_proxy_DE_Frankfurt=$((2048*1024))
check "замер: тег с пробелами -> скорость и код" "$(sb_measure_node 'proxy DE Frankfurt')" "2048 200"
check "правило замера: тег с пробелами целиком" "$(jq -r '.routing.rules[0].outboundTag' "$WORK/last_rule.json")" "proxy DE Frankfurt"
check "правило замера: тег с пробелами, inbound цел" "$(jq -r '.routing.rules[0].inboundTag[0]' "$WORK/last_rule.json")" "probe"

_odd='proxy "q" \b'
sb_measure_node "$_odd" >/dev/null 2>&1
check "правило замера: тег с кавычкой и \ — валидный JSON" "$(jq -e . "$WORK/last_rule.json" >/dev/null 2>&1 && echo ok || echo bad)" "ok"
check "правило замера: тег с кавычкой и \ — без искажений" "$(jq -r '.routing.rules[0].outboundTag' "$WORK/last_rule.json")" "$_odd"

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

# === теги с пробелами: sb_tick целиком ===
# Сквозная регрессия: все четыре места, где тег резался по пробелам (список
# нод, перебор в sb_tick, текущая нода из bi, JSON правила), в одном прогоне.
# Ноды: "proxy DE Frankfurt", "proxy US East 2", "proxy-NL", "proxy * all".
sb_routing_file="$xray_conf_dir/routing_space.json"
sb_outbounds_file="$xray_conf_dir/outbounds_space.json"
sb_balancer="balancer"; sb_hysteresis=25; sb_maxtime=8
sb_log_file="$WORK/sb_tick_space.log"; sb_log_enabled="true"
STUB_OVERRIDE=""
STUB_SPEED_proxy_NL=0; STUB_SPEED_proxy___all=0

# текущая "proxy DE Frankfurt"=1000, кандидат "proxy US East 2"=1200 (+20%) —
# ниже порога. Если текущая определилась как обрезанное "proxy", её скорость
# сочлась бы нулём и переключение случилось бы зря.
rm -f "$sb_log_file"
STUB_CURRENT="proxy DE Frankfurt"; STUB_BO=""
STUB_SPEED_proxy_DE_Frankfurt=$((1000*1024)); STUB_SPEED_proxy_US_East_2=$((1200*1024))
sb_tick >/dev/null 2>&1
check "теги с пробелами: +20% не переключает" "$STUB_BO" ""
check "теги с пробелами: текущая осталась" "$STUB_CURRENT" "proxy DE Frankfurt"
check "теги с пробелами: замер в логе под полным именем" "$(grep -c -F 'замер proxy US East 2: 1200 КБ/с' "$sb_log_file")" "1"
check "теги с пробелами: нет замера обрезанного 'proxy'" "$(grep -c -E 'замер proxy: ' "$sb_log_file")" "0"
check "теги с пробелами: порог в логе назван по полному тегу" "$(grep -c -F 'оставляем proxy DE Frankfurt:' "$sb_log_file")" "1"

# кандидат +30% — переключить, и в bo уйдёт ОДИН аргумент с полным тегом
STUB_CURRENT="proxy DE Frankfurt"; STUB_BO=""
STUB_SPEED_proxy_DE_Frankfurt=$((1000*1024)); STUB_SPEED_proxy_US_East_2=$((1300*1024))
sb_tick >/dev/null 2>&1
check "теги с пробелами: +30% -> bo с полным тегом" "$STUB_BO" "proxy US East 2"
check "теги с пробелами: переключение записано в лог" "$(grep -c -F 'переключение: proxy DE Frankfurt (1000) -> proxy US East 2 (1300 КБ/с)' "$sb_log_file")" "1"

# быстрейшая уже активна — bo не зовётся
rm -f "$sb_log_file"
STUB_CURRENT="proxy US East 2"; STUB_BO=""
sb_tick >/dev/null 2>&1
check "теги с пробелами: быстрейшая активна -> bo не вызван" "$STUB_BO" ""
check "теги с пробелами: лог 'уже активна' с полным тегом" "$(grep -c -F 'быстрейшая нода уже активна: proxy US East 2 (1300 КБ/с)' "$sb_log_file")" "1"

# активная нода задана через Override (как после прошлого bo) — тоже с пробелами
STUB_CURRENT="proxy-NL"; STUB_OVERRIDE="proxy US East 2"; STUB_BO=""
sb_tick >/dev/null 2>&1
check "теги с пробелами: Override-нода с пробелами считается текущей" "$STUB_BO" ""
STUB_OVERRIDE=""

# тег с '*' замеряется как обычный и не рассыпается на файлы каталога
STUB_CURRENT="proxy US East 2"; STUB_BO=""
STUB_SPEED_proxy_DE_Frankfurt=0; STUB_SPEED_proxy_US_East_2=0; STUB_SPEED_proxy___all=$((5000*1024))
sb_tick >/dev/null 2>&1
check "теги с пробелами: нода с '*' выбрана целиком" "$STUB_BO" "proxy * all"

# вернуть дефолтные пути и лог — дальше свои фикстуры
sb_routing_file="$xray_conf_dir/05_routing.json"
sb_outbounds_file="$xray_conf_dir/04_outbounds.json"
sb_log_file="$WORK/sb.log"
STUB_SPEED_proxy___all=0

# === лог: параметр .xray.speed_balancer.log (issue #103) ===
sb_log_file="$WORK/sblog.log"; rm -f "$sb_log_file"
sb_log_enabled="true"; sb_log "строка при включённом логе"
check "лог пишется при sb_log_enabled=true" "$([ -s "$sb_log_file" ] && echo yes || echo no)" "yes"

rm -f "$sb_log_file"
sb_log_enabled="false"; sb_log "строка при выключенном логе"
check "лог молчит при sb_log_enabled=false" "$([ -e "$sb_log_file" ] && echo yes || echo no)" "no"

# сквозь настройки: .log:false -> sb_log_enabled=false
printf '{"xkeen":{"xray":{"speed_balancer":{"log":false}}}}' > "$xkeen_config"
speed_balancer_settings
check "settings: .log false -> sb_log_enabled false" "$sb_log_enabled" "false"
printf '{"xkeen":{"xray":{"speed_balancer":{}}}}' > "$xkeen_config"
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
check "insert: enabled записан"          "$(rjq '.xkeen.xray.speed_balancer.enabled')" "true"
check "insert: policy цела"              "$(rjq '.xkeen.policy[0].name')" "XKeen"
check "insert: комментарий сохранён"     "$(grep -c 'моя политика доступа' "$xkeen_config")" "1"
check "insert: бэкап создан"             "$([ -f "$xkeen_config.bak" ] && echo yes || echo no)" "yes"
check "insert: результат валиден"        "$(strip_json_comments "$xkeen_config" | jq -e . >/dev/null 2>&1 && echo ok || echo bad)" "ok"

# 2) обновление блока: чужие sb-параметры (значения) целы, комментарий снаружи цел
cat > "$xkeen_config" <<'JSON'
{
  "xkeen": {
    "policy": [ { "name": "XKeen" } ],
    "xray": {
      "speed_balancer": {
        "enabled": false,
        "interval": 20,
        "log": false
      }
    },
    "gh_proxy": "example.com"
  }
}
JSON
sb_write_setting enabled true >/dev/null 2>&1; check "update: rc=0" "$?" "0"
check "update: enabled -> true"          "$(rjq '.xkeen.xray.speed_balancer.enabled')" "true"
check "update: чужой interval сохранён"  "$(rjq '.xkeen.xray.speed_balancer.interval')" "20"
check "update: чужой log сохранён"       "$(rjq '.xkeen.xray.speed_balancer.log')" "false"
check "update: соседний gh_proxy цел"    "$(rjq '.xkeen.gh_proxy')" "example.com"
check "update: policy цела"              "$(rjq '.xkeen.policy[0].name')" "XKeen"

# 3) фигурная скобка в чужом комментарии НЕ сбивает счёт скобок блока
cat > "$xkeen_config" <<'JSON'
{
  "xkeen": {
    // порты вида {80,443} и скобка }
    "policy": [ { "name": "XKeen" } ],
    "xray": { "speed_balancer": { "enabled": false } }
  }
}
JSON
sb_write_setting enabled true >/dev/null 2>&1; check "скобки-в-комменте: rc=0" "$?" "0"
# Регрессия jc_set_path (01_info_common.sh, locate_obj): при поиске
# ПРОМЕЖУТОЧНОГО ключа пути ("xray") скобки в комментариях должны
# игнорироваться. Висячая "}" не должна обрывать границу объекта
# .xkeen или приводить к появлению второго одноимённого ключа.
# Сценарий проверяет реальную запись значения в существующий раздел.
check_known "скобки-в-комменте: enabled -> true" "$(rjq '.xkeen.xray.speed_balancer.enabled')" "true"
check "скобки-в-комменте: комментарий цел" "$(grep -c '80,443' "$xkeen_config")" "1"

# 4) пустой .xkeen -> блок добавляется вставкой
printf '{"xkeen":{}}\n' > "$xkeen_config"
sb_write_setting enabled true >/dev/null 2>&1; check "пустой xkeen: rc=0" "$?" "0"
check "пустой xkeen: enabled записан"     "$(jq -r '.xkeen.xray.speed_balancer.enabled' "$xkeen_config")" "true"

# 5) файл {} -> собирается jq-fallback
printf '{}\n' > "$xkeen_config"
sb_write_setting enabled true >/dev/null 2>&1; check "пустой {}: rc=0" "$?" "0"
check "пустой {}: enabled записан"        "$(jq -r '.xkeen.xray.speed_balancer.enabled' "$xkeen_config")" "true"

# 6) структурно битый конфиг (policy без name): запись отклонена, файл не изменён
cat > "$xkeen_config" <<'JSON'
{
  "xkeen": { "policy": [ { "port": "80" } ] }
}
JSON
cp "$xkeen_config" "$WORK/orig_bad.json"
sb_write_setting enabled true >/dev/null 2>&1; check "битая policy: rc=1" "$?" "1"
check "битая policy: sb НЕ добавлен"      "$(rjq '.xkeen.xray.speed_balancer.enabled // "нет"')" "нет"
check "битая policy: файл не изменён"     "$(cmp -s "$xkeen_config" "$WORK/orig_bad.json" && echo same || echo diff)" "same"

# === формат записанного блока: по ключу на строку, с отступом по месту вставки ===
# Блок машинный, но лежит в пользовательском файле рядом с рукописными ключами,
# поэтому пишется читаемым, а не одной строкой.
cat > "$xkeen_config" <<'JSON'
{
  "xkeen": {
    "xray": {
      "speed_balancer": { "enabled": false, "interval": 20 }
    }
  }
}
JSON
sb_write_setting enabled true >/dev/null 2>&1
check "формат update: ключ и '{' на своей строке" "$(grep -c '^      "speed_balancer": {$' "$xkeen_config")" "1"
check "формат update: ключи блока с отступом"     "$(grep -c '^        "enabled": true' "$xkeen_config")" "1"
check "формат update: чужой ключ блока цел"       "$(grep -c '^        "interval": 20' "$xkeen_config")" "1"
check "формат update: закрывающая скобка блока"   "$(grep -c '^      }$' "$xkeen_config")" "1"
check "формат update: файл валиден"               "$(jq -e . "$xkeen_config" >/dev/null 2>&1 && echo ok || echo bad)" "ok"

cat > "$xkeen_config" <<'JSON'
{
  "xkeen": {
    "policy": [ { "name": "XKeen" } ]
  }
}
JSON
sb_write_setting enabled true >/dev/null 2>&1
check "формат insert: ключ и '{' на своей строке" "$(grep -c '^      "speed_balancer": {$' "$xkeen_config")" "1"
check "формат insert: ключи блока с отступом"     "$(grep -c '^        "enabled": true' "$xkeen_config")" "1"
check "формат insert: файл валиден"               "$(jq -e . "$xkeen_config" >/dev/null 2>&1 && echo ok || echo bad)" "ok"

# нестандартный шаг отступа: блок встаёт вровень с соседним ключом, а не по 2
cat > "$xkeen_config" <<'JSON'
{
    "xkeen": {
        "policy": [ { "name": "XKeen" } ]
    }
}
JSON
sb_write_setting enabled true >/dev/null 2>&1
check "формат insert: отступ как у соседа" "$(grep -c '^          "speed_balancer": {$' "$xkeen_config")" "1"

# компактный (однострочный) файл таким и остаётся — переносы там были бы чужеродны
printf '{"xkeen":{"xray":{"speed_balancer":{"enabled":false}}}}\n' > "$xkeen_config"
sb_write_setting enabled true >/dev/null 2>&1
check "формат: однострочный файл не разбит"  "$(awk 'END { print NR }' "$xkeen_config")" "1"
check "формат: однострочный файл валиден"    "$(jq -r '.xkeen.xray.speed_balancer.enabled' "$xkeen_config")" "true"

# === xray остановлен: автонастройка api не предлагается (комментарий к PR #107) ===
# По молчащему api нельзя отличить ненастроенную конфигурацию от настроенной, но
# неработающей — иначе -sb on предлагает добавить уже существующие api и probe.
STUB_XRAY_RUNNING="no"; STUB_MIHOMO_RUNNING="no"; STUB_API_ALIVE="no"
out=$(sb_ensure_api 2>&1); rc=$?
check "xray остановлен: rc=1"                   "$rc" "1"
check "xray остановлен: подсказка -start"       "$(printf '%s' "$out" | grep -c 'xkeen -start')" "1"
check "xray остановлен: без предложения настроить" "$(printf '%s' "$out" | grep -c 'Настроить автоматически')" "0"

STUB_MIHOMO_RUNNING="yes"
out=$(sb_ensure_api 2>&1); rc=$?
check "ядро Mihomo: rc=1"                       "$rc" "1"
check "ядро Mihomo: подсказка -xray"            "$(printf '%s' "$out" | grep -c 'xkeen -xray')" "1"

# статус тоже различает «ядро стоит» и «api не отвечает»
printf '{"xkeen":{"xray":{"speed_balancer":{"enabled":true}}}}\n' > "$xkeen_config"
STUB_MIHOMO_RUNNING="no"
check "status: xray остановлен"  "$(sb_status 2>&1 | grep -c 'Xray не запущен')" "1"
STUB_XRAY_RUNNING="yes"
check "status: api недоступен"   "$(sb_status 2>&1 | grep -c 'недоступен')" "1"

# api и probe настроены — автонастройка не нужна
printf '%s\n' '{"inbounds":[{"tag":"probe","protocol":"http","listen":"127.0.0.1","port":10808}]}' > "$xray_conf_dir/probe_fixture.json"
STUB_API_ALIVE="yes"
sb_ensure_api >/dev/null 2>&1
check "api жив: sb_ensure_api rc=0" "$?" "0"

# === код возврата `xkeen -sb ...` ===
# Второй параметр разбирает модуль, а не case диспетчера: там код операции
# терялся на завершающем shift, и отклонённое включение выглядело успехом.
check "аргумент on"               "$(sb_command_arg on)"     "on"
check "аргумент off"              "$(sb_command_arg off)"    "off"
check "аргумент status"           "$(sb_command_arg status)" "status"
check "аргумент мусор -> пусто"   "$(sb_command_arg wat)"    ""
check "аргумент пустой -> пусто"  "$(sb_command_arg '')"     ""

STUB_XRAY_RUNNING="no"; STUB_API_ALIVE="no"
sb_control on >/dev/null 2>&1
check "sb_control on: отказ -> rc=1" "$?" "1"

STUB_XRAY_RUNNING="yes"; STUB_API_ALIVE="yes"
sb_control on >/dev/null 2>&1
check "sb_control on: успех -> rc=0"        "$?" "0"
check "sb_control on: cron-задача создана"  "$(grep -c 'xkeen -sbt' "$cron_dir/$cron_file")" "1"
check "sb_control on: enabled=true"         "$(rjq '.xkeen.xray.speed_balancer.enabled')" "true"

sb_control status >/dev/null 2>&1
check "sb_control status: rc=0" "$?" "0"

sb_control off >/dev/null 2>&1
check "sb_control off: rc=0"               "$?" "0"
check "sb_control off: cron-задача снята"  "$(grep -c 'xkeen -sbt' "$cron_dir/$cron_file")" "0"
check "sb_control off: enabled=false"      "$(rjq '.xkeen.xray.speed_balancer.enabled')" "false"

# запись настройки не удалась — выключение тоже не выдаёт себя за успех.
# Расписание возвращаем: по пустому cron выключение отрапортовало бы «уже
# выключена» и до записи не дошло бы.
sb_install_cron
printf '{"xkeen":{"policy":[{"port":"80"}]}}\n' > "$xkeen_config"
sb_control off >/dev/null 2>&1
check "sb_control off: конфиг не записан -> rc=1" "$?" "1"

# === повторное включение/выключение ===
# На уже включённой балансировке `-sb on` не включает её заново: сообщает
# состояние, замер не предлагает (см. ниже). «Включено» = настройка И
# cron-задача вместе.
loglines() { awk 'END { print NR }' "$sb_log_file" 2>/dev/null; }

printf '{"xkeen":{}}\n' > "$xkeen_config"
sb_control on </dev/null >/dev/null 2>&1
before=$(loglines)

out=$(sb_control on </dev/null 2>&1); rc=$?
check "повторный on: rc=0"                   "$rc" "0"
check "повторный on: сообщает 'уже включена'" "$(printf '%s' "$out" | grep -c 'уже .*включена')" "1"
# Вызов sb_ask_measure в ветке "уже включена" закомментирован в sb_enable
# (02_balancer_control.sh, комментарий рядом: "при автоустановке с
# использованием нескольких параметров приведет остановке до выбора
# ответа"), поэтому подсказка "Выполнить замер сейчас?" не печатается —
# замер вне расписания сейчас не предлагается. Если вызов вернут —
# ожидание в обеих проверках ниже нужно поменять обратно.
check "повторный on: замер не предложен"      "$(printf '%s' "$out" | grep -c 'Выполнить замер сейчас')" "0"
check "повторный on: без ответа замер не идёт" "$(loglines)" "$before"

# Тот же закомментированный sb_ask_measure: ответ "y" некому читать,
# замер не запускается.
echo y | sb_control on >/dev/null 2>&1
check "повторный on: ответ y не запускает замер" "$([ "$(loglines)" -gt "$before" ] && echo yes || echo no)" "no"

# enabled правили руками в xkeen.json — расписания ещё нет, включение доводится
sb_remove_cron
sb_control on </dev/null >/dev/null 2>&1
check "on без cron: расписание восстановлено" "$(grep -c 'xkeen -sbt' "$cron_dir/$cron_file")" "1"

sb_control off >/dev/null 2>&1
out=$(sb_control off 2>&1); rc=$?
check "повторный off: rc=0"                     "$rc" "0"
check "повторный off: сообщает 'уже выключена'" "$(printf '%s' "$out" | grep -c 'уже .*выключена')" "1"

rm -rf "$WORK"
printf '\n=== пройдено: %s, провалено: %s, известных дефектов: %s ===\n' "$pass" "$fail" "$known"
[ "$fail" -eq 0 ]
