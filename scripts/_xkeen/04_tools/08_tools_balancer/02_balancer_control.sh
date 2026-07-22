# Управление балансировкой по скорости: включение/выключение, автонастройка
# gRPC api Xray, cron, интерактивное меню и статус.

# Жив ли gRPC api (RoutingService). lsrules не зависит от имени балансировщика,
# поэтому годится как проба живости.
sb_api_alive() {
    xray api lsrules -s "$sb_api_addr" >/dev/null 2>&1
}

# Заменить объект .xkeen.speed_balancer его новой версией ($1), сохранив ВЕСЬ
# остальной текст файла ($2) побайтово — включая комментарии на чужих ключах.
# Скобки считаются от '{' самого блока с учётом строк и escape, поэтому фигурные
# скобки в чужих комментариях/строках счёт не сбивают. На stdout — результат.
# Код возврата: 0 — заменено; 3 — ключа speed_balancer нет (нужна вставка);
# иное — блок найден, но не удалось сматчить скобки (повреждён).
_sb_replace_block() {
    SB_NEW="$1" awk '
    { buf = buf $0 "\n" }
    END {
      new = ENVIRON["SB_NEW"]; key = "\"speed_balancer\""
      kp = index(buf, key)
      if (kp == 0) { printf "%s", buf; exit 3 }
      i = kp + length(key); n = length(buf)
      while (i <= n && substr(buf,i,1) != "{") i++
      if (i > n) { printf "%s", buf; exit 4 }
      depth=0; instr=0; esc=0
      for (; i <= n; i++) {
        c = substr(buf,i,1)
        if (instr) { if (esc) esc=0; else if (c=="\\") esc=1; else if (c=="\"") instr=0 }
        else { if (c=="\"") instr=1; else if (c=="{") depth++;
               else if (c=="}") { depth--; if (depth==0) { ve=i; break } } }
      }
      if (depth != 0) { printf "%s", buf; exit 5 }
      printf "%s%s: %s%s", substr(buf,1,kp-1), key, new, substr(buf,ve+1)
    }' "$2"
}

# Вставить блок speed_balancer ($1) в существующий объект .xkeen файла ($2),
# сразу после его открывающей '{'. Прочий текст сохраняется. Код возврата:
# 0 — вставлено; 3 — объекта .xkeen нет (нужен jq-fallback).
_sb_insert_block() {
    SB_NEW="$1" awk '
    { buf = buf $0 "\n" }
    END {
      new = ENVIRON["SB_NEW"]; key = "\"xkeen\""
      kp = index(buf, key)
      if (kp == 0) { printf "%s", buf; exit 3 }
      i = kp + length(key); n = length(buf)
      while (i <= n && substr(buf,i,1) != "{") i++
      if (i > n) { printf "%s", buf; exit 3 }
      j = i + 1
      while (j <= n && substr(buf,j,1) ~ /[ \t\r\n]/) j++
      before = substr(buf,1,i); after = substr(buf,i+1)
      if (substr(buf,j,1) == "}")
        printf "%s\n    \"speed_balancer\": %s\n  %s", before, new, after
      else
        printf "%s\n    \"speed_balancer\": %s,%s", before, new, after
    }' "$2"
}

# Обновить ОДИН ключ .xkeen.speed_balancer.KEY = VALUE в xkeen.json, трогая ТОЛЬКО
# блок балансера. Весь остальной файл (policy, geodata, комментарии) сохраняется
# как есть — XKeen сам xkeen.json не переписывает, и балансер тоже не должен.
#
# Как: новый блок собирается через jq (текущий speed_balancer + этот ключ, чтобы
# сохранить значения прочих параметров), затем ТЕКСТОВО вставляется на место
# старого блока (_sb_replace_block / _sb_insert_block). Комментарии/формат ВНУТРИ
# блока балансера при этом нормализуются — блок машинный; всё вне блока цело.
#
# Страховка: перед записью — реальный бэкап; результат проходит синтаксис (jq -e .)
# и структуру (тем же критерием, что валидатор старта: policy, если есть, — массив
# объектов с name). При любом сбое конфиг восстанавливается из бэкапа, так что
# ошибка текстовой хирургии не оставит битый файл.
sb_write_setting() {
    local key raw val new tmp bak struct_ok rc
    key="$1"; raw="$2"
    case "$raw" in
        true|false)   val="$raw" ;;
        ''|*[!0-9]*)  val="\"$raw\"" ;;   # строка -> в кавычки
        *)            val="$raw" ;;       # число как есть
    esac

    command -v jq >/dev/null 2>&1 || { echo "  jq не найден — настройку не записать"; return 1; }
    [ -f "$xkeen_config" ] || printf '{}\n' > "$xkeen_config"

    new=$(strip_json_comments "$xkeen_config" \
        | jq -c --arg k "$key" --argjson v "$val" '(.xkeen.speed_balancer // {}) | .[$k] = $v' 2>/dev/null)
    [ -n "$new" ] || { echo "  Не удалось разобрать xkeen.json — настройку не записать"; return 1; }

    bak="$xkeen_config.bak"
    cp "$xkeen_config" "$bak" 2>/dev/null

    tmp="$xkeen_config.sb.tmp"
    _sb_replace_block "$new" "$xkeen_config" > "$tmp"; rc=$?
    if [ "$rc" = 3 ]; then                       # блока ещё нет — вставить в .xkeen
        _sb_insert_block "$new" "$xkeen_config" > "$tmp"; rc=$?
    fi
    if [ "$rc" = 3 ]; then                        # нет и .xkeen (реально — только {})
        strip_json_comments "$xkeen_config" \
            | jq --argjson sb "$new" '.xkeen.speed_balancer = $sb' > "$tmp" 2>/dev/null; rc=$?
    fi

    # Критерий структуры повторяет validate_xkeen_json (04_register_init.sh):
    # менять его надо синхронно в обоих местах.
    struct_ok='
      if has("xkeen") and .xkeen != null then
        if .xkeen.policy then
          .xkeen.policy | type == "array" and ([.[] | select(has("name") | not)] | length == 0)
        else true end
      else true end'

    # Валидируем через strip: в tmp теперь СОХРАНЕНЫ комментарии, и голый jq на
    # них упал бы, ложно забраковав корректный результат.
    if [ "$rc" = 0 ] && strip_json_comments "$tmp" | jq -e . >/dev/null 2>&1 \
       && strip_json_comments "$tmp" | jq -e "$struct_ok" >/dev/null 2>&1; then
        mv "$tmp" "$xkeen_config"
        return 0
    fi

    # Сбой хирургии или проверки: не оставляем ни битого tmp, ни повреждённого конфига.
    rm -f "$tmp"
    [ -f "$bak" ] && cp "$bak" "$xkeen_config" 2>/dev/null
    echo "  Не удалось безопасно обновить блок балансера в $xkeen_config (восстановлено из бэкапа)"
    return 1
}

# Гарантировать наличие рабочего gRPC api и probe-inbound. Если api уже живой —
# ничего не делает. Иначе с подтверждением добавляет api-блок, probe-inbound и
# правило маршрутизации api, проверяет конфиг и перезапускает Xray.
#
# Правило api пишется ПЕРВЫМ прямо в routing-файл (по умолчанию 05_routing.json),
# а не отдельным файлом: Xray при мердже confdir заменяет routing.rules последним
# файлом, а не склеивает — правило из отдельного файла потерялось бы. Обновление и
# переустановка XKeen существующий routing-файл не перезаписывают, поэтому правило
# сохраняется; но при РУЧНОЙ перегенерации роутинга (например смене outbound'ов)
# его нужно вернуть повторным `xkeen -sb on`. Это известное ограничение.
sb_ensure_api() {
    sb_api_alive && return 0

    echo
    echo -e "  Для балансировки нужен gRPC api Xray (${yellow}RoutingService${reset}) и probe-inbound для замера."
    printf "  Настроить автоматически? Будут добавлены api и probe, конфигурация Xray перезапущена. [y/N]: "
    read -r ans
    case "$ans" in
        [Yy]*) ;;
        *) echo "  Отменено. Ручная настройка описана в docs/commands.md."; return 1 ;;
    esac

    local bkp
    bkp="$backups_dir/xray-configs-sb-$(date +%s)"
    mkdir -p "$bkp" && cp "$xray_conf_dir"/*.json "$bkp"/ 2>/dev/null
    echo -e "  Бэкап конфигурации Xray: ${yellow}$bkp${reset}"

    # api-блок + api-inbound + probe-inbound одним файлом (мержатся по tag)
    cat > "$sb_api_config" <<EOF
{
  "api": { "tag": "api", "services": ["RoutingService", "StatsService"] },
  "inbounds": [
    { "tag": "api", "listen": "127.0.0.1", "port": 10085,
      "protocol": "dokodemo-door", "settings": { "address": "127.0.0.1" } },
    { "tag": "probe", "listen": "127.0.0.1", "port": 10808,
      "protocol": "http", "settings": {} }
  ]
}
EOF

    # api-правило первым в основной routing.rules, если его там ещё нет
    local rjson has_rule
    rjson="$sb_routing_file"
    if [ -f "$rjson" ]; then
        has_rule=$(strip_json_comments "$rjson" \
            | jq '[.routing.rules[]? | select(.outboundTag=="api")] | length' 2>/dev/null)
        if [ "${has_rule:-0}" = "0" ]; then
            if strip_json_comments "$rjson" \
                | jq '.routing.rules = ([{type:"field",inboundTag:["api"],outboundTag:"api"}] + (.routing.rules // []))' \
                  > "$rjson.tmp" 2>/dev/null && jq -e . "$rjson.tmp" >/dev/null 2>&1; then
                mv "$rjson.tmp" "$rjson"
            else
                rm -f "$rjson.tmp"
                echo -e "  ${red}✗${reset} Не удалось добавить правило api в $rjson"
                cp "$bkp"/*.json "$xray_conf_dir"/ 2>/dev/null
                return 1
            fi
        fi
    fi

    # проверка конфига до рестарта — битый конфиг не должен убить ядро
    if ! XRAY_LOCATION_ASSET="$geo_dir" xray run -confdir "$xray_conf_dir" -test >/dev/null 2>&1; then
        echo -e "  ${red}✗${reset} Конфигурация не прошла проверку — восстанавливаю из бэкапа"
        cp "$bkp"/*.json "$xray_conf_dir"/ 2>/dev/null
        return 1
    fi

    echo -e "  ${yellow}Перезапуск${reset} XKeen для применения api..."
    "$initd_file" restart >/dev/null 2>&1 || "$install_dir/xkeen" -restart >/dev/null 2>&1

    local i=0
    while [ "$i" -lt 20 ]; do
        sb_api_alive && { echo -e "  api ${green}поднят${reset}"; return 0; }
        i=$((i + 1)); sleep 1
    done
    echo -e "  ${red}✗${reset} api не поднялся за 20с — проверьте $xray_error_log"
    return 1
}

# Cron-задача периодического замера. Формат совпадает с install_cron.
sb_install_cron() {
    local path
    path="$cron_dir/$cron_file"
    mkdir -p "$cron_dir"; touch "$path"; chmod +x "$path"
    grep -v "$install_dir/xkeen -sbt" "$path" > "$path.tmp" 2>/dev/null
    mv "$path.tmp" "$path"
    printf '*/%s * * * * %s/xkeen -sbt\n' "$sb_interval" "$install_dir" >> "$path"
    sed -i '/^$/d' "$path"
}

sb_remove_cron() {
    local path
    path="$cron_dir/$cron_file"
    [ -f "$path" ] || return 0
    grep -v "$install_dir/xkeen -sbt" "$path" > "$path.tmp" 2>/dev/null
    mv "$path.tmp" "$path"
    sed -i '/^$/d' "$path"
}

sb_enable() {
    speed_balancer_settings
    sb_ensure_api || { echo -e "  ${red}✗${reset} Балансировка не включена: нет рабочего api."; return 1; }
    sb_write_setting enabled true || return 1
    sb_install_cron
    echo -e "  ${green}✔${reset} Балансировка по скорости включена (замер каждые ${yellow}$sb_interval${reset} мин)."
    echo -e "  Первый замер выполняется сейчас..."
    speed_balancer_settings
    sb_tick
    echo -e "  Готово. Текущая нода: ${yellow}$(sb_current_target)${reset}"
}

sb_disable() {
    speed_balancer_settings
    # снять override — без него выбор залипнет на последней ноде (у bo нет TTL)
    xray api bo -s "$sb_api_addr" -b "$sb_balancer" -r >/dev/null 2>&1
    sb_remove_cron
    sb_write_setting enabled false
    echo -e "  ${green}✔${reset} Балансировка по скорости выключена, override снят."
}

sb_status() {
    speed_balancer_settings
    echo
    if [ "$sb_enabled" = "true" ]; then
        echo -e "  Балансировка по скорости: ${green}включена${reset}"
    else
        echo -e "  Балансировка по скорости: ${yellow}выключена${reset}"
    fi
    echo -e "  Балансировщик: ${yellow}$sb_balancer${reset}   Интервал: ${yellow}$sb_interval${reset} мин   Гистерезис: ${yellow}$sb_hysteresis${reset}%"
    if sb_api_alive; then
        echo -e "  Текущая нода: ${yellow}$(sb_current_target)${reset}"
    else
        echo -e "  api Xray (${yellow}$sb_api_addr${reset}) недоступен"
    fi
    if [ "$sb_log_enabled" != "false" ] && [ -f "$sb_log_file" ]; then
        echo "  Последние события:"
        tail -n 8 "$sb_log_file" | sed 's/^/    /'
    fi
}

# Интерактивное меню (стиль main: printf + read + case).
sb_menu() {
    local choice
    while true; do
        sb_status
        speed_balancer_settings
        echo
        if [ "$sb_enabled" = "true" ]; then
            printf '     1. Выключить балансировку\n'
        else
            printf '     1. Включить балансировку\n'
        fi
        printf '     2. Прогнать замер сейчас\n'
        printf '     0. Выход\n\n'
        printf '  Ваш выбор: '
        # read возвращает ненулевой код на EOF (нет TTY: пайп, ssh без -t, cron).
        # Без этой проверки пустой ввод уходил бы в ветку * и while true крутился
        # бы вплотную — CPU-spin. EOF трактуем как выход из меню.
        read -r choice || { echo; return 0; }
        case "$choice" in
            0) return 0 ;;
            1)
                speed_balancer_settings
                if [ "$sb_enabled" = "true" ]; then sb_disable; else sb_enable; fi
                ;;
            2)
                speed_balancer_settings
                if [ "$sb_enabled" = "true" ]; then
                    echo -e "  ${yellow}Замер...${reset}"; sb_tick; echo -e "  ${green}✔${reset} Замер завершён."
                else
                    echo "  Сначала включите балансировку."
                fi
                ;;
            *) echo "  Неверный ввод. Введите 1, 2 или 0." ;;
        esac
    done
}
