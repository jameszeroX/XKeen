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
    local url="$1"
    local dest_file="$2"
    local display_name="$3"
    local ip_type="$4"

    local _validator_name="_validate_geoipset_v4"
    if [ "$ip_type" != "ipv4" ]; then
        _validator_name="_validate_geoipset_v6"
    fi

    # Получаем ожидаемый размер файла
    local expected_size=""
    printf "  Запрос информации о %s...\n" "$display_name"

    if expected_size=$(_get_expected_size "$url"); then
        printf "  Ожидаемый размер: ${yellow}%s байт${reset}\n" "$expected_size"
    else
        printf "  ${yellow}Предупреждение${reset}: Не удалось определить ожидаемый размер файла\n"
        expected_size=""
    fi

    local tmp_file="${dest_file}.tmp.$$"

    if _download_and_validate_loop "$url" "$tmp_file" "$expected_size" "$_validator_name" "$display_name"; then
        mv -f "$tmp_file" "$dest_file"
    else
        # Обработка ошибок, если все попытки провалились
        case "$_last_error" in
            html_stub)
                printf "  ${red}Ошибка${reset}: получена HTML-страница вместо списка IP\n"
                ;;
            content_v4)
                printf "  ${red}Ошибка${reset}: %s не содержит корректных IPv4-адресов\n" "$display_name"
                ;;
            content_v6)
                printf "  ${red}Ошибка${reset}: %s не содержит корректных IPv6-адресов\n" "$display_name"
                ;;
            size|size_mismatch)
                printf "  ${red}Ошибка${reset}: Размер загруженного файла не соответствует ожидаемому\n"
                ;;
            *)
                local max_attempts=${retries_download:-1}
                if [ "$max_attempts" -gt 1 ]; then
                    printf "  ${red}Ошибка${reset}: не удалось загрузить %s после %d попыток\n" "$display_name" "$max_attempts"
                else
                    printf "  ${red}Ошибка${reset}: не удалось загрузить %s\n" "$display_name"
                fi
                ;;
        esac
        printf "  ${yellow}Инфо${reset}: Невозможно обновить %s. ${green}Оставляем старый файл${reset}\n\n" "$display_name"
        return 1
    fi

    [ "$action" = "init" ] && msg_geoipset="установлен" || msg_geoipset="обновлён"
    printf "  %s ${green}успешно $msg_geoipset${reset}\n\n" "$display_name"
    return 0
}

load_geoipset() {
    local set="$1"
    local file="$2"
    local family="$3"
    local tmp="${set}_tmp"

    # Заполняем tmp; основной набор подменяется только после успешного restore
    ipset create "$set" hash:net family "$family" -exist
    ipset create "$tmp" hash:net family "$family" -exist
    ipset flush "$tmp"

    if [ -f "$file" ] && awk '/^[0-9a-fA-F]/ {print "add '"$tmp"' "$1}' "$file" | ipset restore -exist; then
        ipset swap "$set" "$tmp"
    fi
    ipset destroy "$tmp"
}

# issue #89: упрощённый install-time детект "безшлюзового" WAN (IPv4, только
# таблица main). Если основной default — on-link заглушка без шлюза (типично
# для mobile/CGNAT WAN, где рабочий маршрут провайдера лежит в отдельной
# policy-таблице "from <WAN-IP> lookup N"), ядро не форвардит транзитный
# трафик клиентов мимо XKeen, и правило-исключение GeoIPSET (geo_exclude
# -j RETURN) не имеет эффекта: сайты РФ перестают открываться. Возвращает 0,
# если WAN похож на такой случай, иначе 1. Только для предупреждения — сама
# установка/загрузка списков не блокируется.
_geoipset_wan_default_broken() {
    command -v ip >/dev/null 2>&1 || return 1

    # default-маршрут(ы) main; unreachable/blackhole не годятся для форвардинга.
    # При нескольких default берём с наименьшей metric — его выбрало бы ядро.
    _gwb_def=$(ip -4 route show default 2>/dev/null | grep -v -e 'unreachable' -e 'blackhole' | awk '
        NF {
            m = 0
            for (i = 1; i <= NF; i++) if ($i == "metric") m = $(i + 1)
            print m, $0
        }
    ' | sort -n | sed -n '1s/^[0-9]* //p')

    [ -z "$_gwb_def" ] && return 1

    # Есть "via <шлюз>" — полноценный маршрут, форвард работает штатно (Ethernet)
    case "$_gwb_def" in
        *" via "*) return 1 ;;
    esac

    _gwb_if=$(printf '%s\n' "$_gwb_def" | sed -n 's/.*[[:space:]]dev[[:space:]]\([^[:space:]]*\).*/\1/p')
    [ -z "$_gwb_if" ] && return 1

    # Point-to-point устройствам (PPPoE/L2TP/SSTP/WireGuard/tun) шлюз не нужен,
    # форвард у них идёт и без via — это не наш случай.
    _gwb_type=$(cat "/sys/class/net/$_gwb_if/type" 2>/dev/null)
    case "$_gwb_type" in
        512|65534|768|769|776|778|823) return 1 ;;  # ppp/none(tun,wg)/tunnel/gre/sit
        *) return 0 ;;
    esac
}

# issue #89: предупреждение о несовместимости GeoIPSET с "безшлюзовым" WAN.
# "$1" — action ("init"/"update"), меняет только финальную рекомендацию.
_warn_geoipset_wan_incompatible() {
    printf "\n  ${yellow}Предупреждение${reset}: похоже, WAN-подключение мобильное (LTE) или\n"
    printf "  CGNAT, и в основной таблице маршрутизации нет шлюза для транзитного\n"
    printf "  трафика клиентов (default ... scope link, без via). На таком WAN\n"
    printf "  GeoIPSET ${yellow}не работает${reset}: правило-исключение для российских адресов не\n"
    printf "  форвардится, и сайты РФ перестанут открываться при включённом\n"
    printf "  проксировании.\n"
    if [ "$1" = "update" ]; then
        printf "  Рекомендуем отключить GeoIPSET: ${yellow}xkeen -dgips${reset}\n"
    else
        printf "  Рекомендуем отказаться от установки (пункт ${yellow}0${reset} в меню ниже)\n"
    fi
    printf "  Подробнее: Known Issues в вики проекта, issue #89:\n"
    printf "  https://github.com/jameszeroX/XKeen/issues/89\n\n"
}

install_geoipset() {
    local action="$1"

    _geoipset_wan_default_broken && _warn_geoipset_wan_incompatible "$action"

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
                        mkdir -p "$ipset_cfg" || { echo "Ошибка: Не удалось создать директорию $ipset_cfg"; exit 1; }
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

    if [ -d "$ipset_cfg" ]; then
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
    
        # Последовательная загрузка списков вместо параллельной для совместимости с прогресс-баром
        [ "$do_v4" = "1" ] && install_geoipset_lst "$geoipv4_url" "$ru_exclude_ipv4" "IPv4 (IPSet)" "ipv4"
        [ "$do_v6" = "1" ] && install_geoipset_lst "$geoipv6_url" "$ru_exclude_ipv6" "IPv6 (IPSet)" "ipv6"
        [ "$do_v4" = "1" ] && load_geoipset geo_exclude "$ru_exclude_ipv4" inet
        [ "$do_v6" = "1" ] && load_geoipset geo_exclude6 "$ru_exclude_ipv6" inet6
    
        if [ ! -f "$ru_override" ]; then
            cat << EOF > "$ru_override"

# Добавьте IP и подсети, которые нужно исключить из IPSET ru_exclude
EOF
        fi
    fi
}