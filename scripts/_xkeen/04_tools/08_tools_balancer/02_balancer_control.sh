# Управление балансировкой по скорости: включение/выключение, автонастройка
# gRPC api Xray, cron, интерактивное меню и статус.

# Жив ли gRPC api (RoutingService). lsrules не зависит от имени балансировщика,
# поэтому годится как проба живости.
sb_api_alive() {
    xray api lsrules -s "$sb_api_addr" >/dev/null 2>&1
}

# Запущен ли Xray. Отдельно от sb_api_alive: у остановленного ядра api молчит
# независимо от того, настроен он или нет, и по одной пробе живости уже
# настроенная конфигурация неотличима от ненастроенной.
sb_xray_running() {
    pidof xray >/dev/null 2>&1
}

# Обновить ОДИН ключ .xkeen.xray.speed_balancer.KEY = VALUE в xkeen.json, трогая
# ТОЛЬКО блок балансера. Весь остальной файл (policy, geodata, комментарии)
# сохраняется как есть — XKeen сам xkeen.json не переписывает, и балансер тоже
# не должен.
#
# Как: новый блок собирается через jq (текущий speed_balancer + этот ключ, чтобы
# сохранить значения прочих параметров), затем ТЕКСТОВО вставляется на место
# старого блока (jc_set_path — универсальная функция, см. её описание выше).
# Комментарии/формат ВНУТРИ блока балансера при этом нормализуются — блок
# машинный; всё вне блока цело.
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

    validate_xkeen_json_syntax || return 1

    # jq без -c: блок пишется в файл человекочитаемым, по ключу на строку —
    # выравнивание по месту вставки делает сама jc_set_path.
    new=$(strip_json_comments "$xkeen_config" \
        | jq --arg k "$key" --argjson v "$val" '(.xkeen.xray.speed_balancer // {}) | .[$k] = $v' 2>/dev/null)
    [ -n "$new" ] || { echo "  Не удалось разобрать xkeen.json — настройку не записать"; return 1; }

    bak="$xkeen_config.bak"
    cp "$xkeen_config" "$bak" 2>/dev/null

    # jc_set_path сама решает: заменить существующий блок (rc=0) или вставить
    # недостающий хвост пути хоть в .xkeen.xray, хоть в .xkeen, хоть прямо в
    # корень файла, если нет вообще ничего (rc=1) — четыре прежних варианта
    # (_sb_replace_block / _sb_insert_into_xray / _sb_insert_xray_into_xkeen /
    # jq-фолбэк по всему файлу) больше не нужны, а rc=2/4 (конфликт типов или
    # битый файл) обрабатываются общей веткой отката ниже, как раньше делал
    # любой "иной" код возврата.
    tmp="$xkeen_config.sb.tmp"
    jc_set_path "xkeen.xray.speed_balancer" "$new" "$xkeen_config" > "$tmp"; rc=$?

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
    if { [ "$rc" = 0 ] || [ "$rc" = 1 ]; } && strip_json_comments "$tmp" | jq -e . >/dev/null 2>&1 \
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
    # Пока Xray не запущен, api молчит и по нему нельзя судить, настроены ли уже
    # api и probe: предложение «настроить автоматически» здесь означало бы
    # повторное добавление того, что в конфигурации уже есть.
    if ! sb_xray_running; then
        echo
        if pidof mihomo >/dev/null 2>&1; then
            echo -e "  Балансировка по скорости работает только с ядром ${yellow}Xray${reset} — сейчас запущен ${yellow}Mihomo${reset}."
            echo -e "  Переключить ядро: '${green}xkeen -xray${reset}'"
        else
            echo -e "  ${yellow}XKeen${reset} остановлен — состояние api и probe определить нельзя."
            echo -e "  Запустите ${yellow}XKeen${reset} командой '${green}xkeen -start${reset}' и повторите '${green}xkeen -sb on${reset}'"
        fi
        return 1
    fi

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
  "api": {
    "services": [
      "RoutingService",
      "StatsService"
    ],
    "tag": "api"
  },
  "inbounds": [
    {
      "protocol": "tunnel",
      "listen": "127.0.0.1",
      "port": 10085,
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },
    {
      "protocol": "http",
      "listen": "127.0.0.1",
      "port": 10808,
      "tag": "probe"
    }
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
            # без "type": "field" — поле deprecated с xray-core v1.8.10 и правилу не нужно
            if strip_json_comments "$rjson" \
                | jq '.routing.rules = ([{inboundTag:["api"],outboundTag:"api"}] + (.routing.rules // []))' \
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
    "$install_dir/xkeen" -restart >/dev/null 2>&1

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

sb_cron_installed() {
    grep -q "$install_dir/xkeen -sbt" "$cron_dir/$cron_file" 2>/dev/null
}

# Предложение прогнать замер вне расписания. Без TTY (cron, ssh без -t, пайп)
# read возвращает EOF — трактуем как отказ, чтобы вызов из скрипта не завис.
sb_ask_measure() {
    local ans
    printf "  Выполнить замер сейчас? [y/N]: "
    read -r ans || { echo; return 0; }
    case "$ans" in
        [Yy]*) ;;
        *) return 0 ;;
    esac
    echo -e "  ${yellow}Замер...${reset}"
    sb_tick
    echo -e "  ${green}✔${reset} Замер завершён. Текущая нода: ${yellow}$(sb_current_target)${reset}"
}

# Балансировка считается включённой, только когда настройка и cron-задача есть
# обе: enabled правят и руками в xkeen.json, и тогда расписание ещё не стоит —
# такой полувключённый случай нужно доводить до конца, а не рапортовать «уже».
sb_enable() {
    speed_balancer_settings
    # причина уже напечатана внутри sb_ensure_api — здесь только итог.
    # Проверка идёт и при повторном включении: молчащий api означает, что
    # правило api потеряно (например при ручной перегенерации роутинга).
    sb_ensure_api || { echo -e "  ${red}✗${reset} Балансировка не включена."; return 1; }

    if [ "$sb_enabled" = "true" ] && sb_cron_installed; then
        echo
        echo -e "  Балансировка по скорости уже ${green}включена${reset} (замер каждые ${yellow}$sb_interval${reset} мин)."
        echo -e "  Текущая нода: ${yellow}$(sb_current_target)${reset}"
        # при автоустановке с использованием нескольких параметров приведет остановке до выбора ответа
        # sb_ask_measure
        return 0
    fi

    sb_write_setting enabled true || return 1
    sb_install_cron
    echo
    echo -e "  ${green}✔${reset} Балансировка по скорости включена (замер каждые ${yellow}$sb_interval${reset} мин)."
    echo -e "  Первый замер выполняется сейчас..."
    speed_balancer_settings
    sb_tick
    echo -e "  Готово. Текущая нода: ${yellow}$(sb_current_target)${reset}"
}

sb_disable() {
    speed_balancer_settings
    if [ "$sb_enabled" != "true" ] && ! sb_cron_installed; then
        echo
        echo -e "  Балансировка по скорости уже ${yellow}выключена${reset}."
        return 0
    fi
    # снять override — без него выбор залипнет на последней ноде (у bo нет TTL)
    xray api bo -s "$sb_api_addr" -b "$sb_balancer" -r >/dev/null 2>&1
    sb_remove_cron
    sb_write_setting enabled false || return 1
    echo
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
    elif ! sb_xray_running; then
        echo -e "  Xray не запущен — текущая нода неизвестна"
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

# Второй параметр `xkeen -sb`, если это распознанная команда; иначе пусто.
# Аналог get_state_arg диспетчера, но для трёх команд балансировки.
sb_command_arg() {
    case "$1" in
        on|off|status) echo "$1" ;;
    esac
}

# Точка входа `xkeen -sb [on|off|status]`. Разбор команды здесь, а не в case
# диспетчера: там код завершения операции терялся на завершающем shift, и
# `xkeen -sb on` возвращал 0 даже когда включение было отклонено.
sb_control() {
    case "$1" in
        on)     smart_clear; sb_enable ;;
        off)    smart_clear; sb_disable ;;
        status) sb_status ;;
        *)      smart_clear; sb_menu ;;
    esac
}
