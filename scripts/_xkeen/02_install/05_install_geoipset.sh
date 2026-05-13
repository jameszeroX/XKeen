# Валидаторы для fetch_with_mirrors: проверяют размер + базовый синтаксис
# содержимого (catch HTML-stub и мусор от proxy-error-page).
_validate_geoipset_v4() {
    _validate_default "$1" "$2" || return 1
    if ! grep -q "^[0-9]" "$1"; then
        _last_error="content_v4"
        return 1
    fi
    return 0
}

_validate_geoipset_v6() {
    _validate_default "$1" "$2" || return 1
    if ! grep -q ":" "$1"; then
        _last_error="content_v6"
        return 1
    fi
    return 0
}

# Функция для установки и обновления GeoIPSET
install_geoipset_lst() {
    mkdir -p "$ipset_cfg" || { echo "Ошибка: Не удалось создать директорию $ipset_cfg"; exit 1; }

    url="$1"
    dest_file="$2"
    display_name="$3"
    ip_type="$4"

    printf "  Загрузка %s...\n" "$display_name"

    if [ "$ip_type" = "ipv4" ]; then
        _validator_name="_validate_geoipset_v4"
    else
        _validator_name="_validate_geoipset_v6"
    fi

    if ! fetch_with_mirrors "$url" "$dest_file" 0 "$_validator_name"; then
        case "$_last_error" in
            html_stub)
                printf "  ${red}Ошибка${reset}: получена HTML-страница вместо списка IP\n  Оставляем старый файл\n\n"
                ;;
            content_v4)
                printf "  ${red}Ошибка${reset}: %s не содержит корректных IPv4-адресов\n  Оставляем старый файл\n\n" "$display_name"
                ;;
            content_v6)
                printf "  ${red}Ошибка${reset}: %s не содержит корректных IPv6-адресов\n  Оставляем старый файл\n\n" "$display_name"
                ;;
            *)
                printf "  ${red}Ошибка${reset}: не удалось загрузить %s\n\n" "$display_name"
                ;;
        esac
        return 1
    fi

    [ "$action" = "init" ] && msg_geoipset="установлен" || msg_geoipset="обновлён"
    printf "  %s ${green}успешно $msg_geoipset${reset}\n\n" "$display_name"
    return 0
}

load_geoipset() {
    set="$1"
    file="$2"
    family="$3"
    tmp="${set}_tmp"

    # Заполняем tmp; основной набор подменяется только после успешного restore
    ipset create "$set" hash:net family "$family" -exist
    ipset create "$tmp" hash:net family "$family" -exist
    ipset flush "$tmp"

    if [ -f "$file" ] && awk '/^[0-9a-fA-F]/ {print "add '"$tmp"' "$1}' "$file" | ipset restore -exist; then
        ipset swap "$set" "$tmp"
    fi
    ipset destroy "$tmp"
}

install_geoipset() {
    action="$1"

    if [ "$action" = "init" ]; then
        # Без TTY (cron, ssh -T) read получает EOF, default-case крутит while true
        # бесконечно: процесс висит в R-state с CPU-spin. Дефолтим выбор на "1"
        # (установить), потому что xkeen -gips из cron это типичный
        # non-interactive caller, где пользователь явно ожидает установку.
        if [ ! -t 0 ]; then
            printf "  Не интерактивный режим (нет TTY): автоматическая установка GeoIPSET\n"
            bypass_cron_geoipset=false
        else
            while true; do
                printf "\n  Желаете исключить российские IP-адреса из проксирования?\n\n"
                printf "     1. Загрузить и установить в исключения IP-подсети России (${yellow}GeoIPSET${reset})\n"
                printf "     0. Пропустить\n\n"
                printf "  Ваш выбор: "
                read -r choice

                case "$choice" in
                    0)
                        printf "  Пропуск установки списков GeoIPSET\n\n"

                        if [ ! -f "$ru_exclude_ipv4" ] && [ ! -f "$ru_exclude_ipv6" ]; then
                            bypass_cron_geoipset=true
                        fi
                        return 0
                        ;;
                    1)
                        bypass_cron_geoipset=false
                        break
                        ;;
                    *)
                        printf "  Неверный ввод. Пожалуйста, введите 1 или 0.\n"
                        ;;
                esac
            done
        fi
    fi

    local do_v4=0 do_v6=0
    if ip -4 addr show 2>/dev/null | grep -q "inet " && command -v iptables >/dev/null 2>&1; then
        if [ "$action" = "init" ] || [ -f "$ru_exclude_ipv4" ]; then
            do_v4=1
        fi
    fi
    if ip -6 addr show 2>/dev/null | grep -q "inet6 fe80::" && command -v ip6tables >/dev/null 2>&1; then
        if [ "$action" = "init" ] || [ -f "$ru_exclude_ipv6" ]; then
            do_v6=1
        fi
    fi

    # Параллельная загрузка независимых списков
    local _pids=""
    [ "$do_v4" = "1" ] && { install_geoipset_lst "$geoipv4_url" "$ru_exclude_ipv4" "IPv4 (IPSet)" "ipv4" & _pids="$_pids $!"; }
    [ "$do_v6" = "1" ] && { install_geoipset_lst "$geoipv6_url" "$ru_exclude_ipv6" "IPv6 (IPSet)" "ipv6" & _pids="$_pids $!"; }
    [ -n "$_pids" ] && wait $_pids

    [ "$do_v4" = "1" ] && load_geoipset geo_exclude "$ru_exclude_ipv4" inet
    [ "$do_v6" = "1" ] && load_geoipset geo_exclude6 "$ru_exclude_ipv6" inet6
}