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

    # Если переменная retries_download не задана, используем одну попытку
    local max_attempts=1
    if [ -n "$retries_download" ] && [ "$retries_download" -gt 1 ] 2>/dev/null; then
        max_attempts=$retries_download
    fi

    local delay=${retry_delay_download:-2}

    if [ "$ip_type" = "ipv4" ]; then
        _validator_name="_validate_geoipset_v4"
    else
        _validator_name="_validate_geoipset_v6"
    fi

    # Получаем ожидаемый размер файла
    local expected_size=""
    printf "  Запрос информации о %s...\n" "$display_name"
    expected_size=$(_get_expected_size "$url")
    if [ $? -eq 0 ]; then
        printf "  Ожидаемый размер: ${yellow}%s байт${reset}\n" "$expected_size"
    else
        printf "  ${yellow}Предупреждение${reset}: Не удалось определить ожидаемый размер файла\n"
        expected_size=""
    fi

    local attempt=1
    local success=1
    local tmp_file="${dest_file}.tmp.$$"

    while [ "$attempt" -le "$max_attempts" ]; do
        # Выводим инфо о попытках только если их больше одной
        if [ "$max_attempts" -gt 1 ]; then
            printf "  Загрузка %s (Попытка %d из %d)...\n" "$display_name" "$attempt" "$max_attempts"
        else
            printf "  Загрузка %s...\n" "$display_name"
        fi

        if fetch_with_mirrors "$url" "$tmp_file" 0 "$_validator_name"; then
            # Проверяем размер загруженного файла
            printf "  Проверка размера %s...\n" "$display_name"
            if _validate_file_with_size "$tmp_file" "$expected_size" 0; then
                # Успешно - перемещаем файл на место
                printf "  ${green}✔ OK${reset} - Размер файла совпал с ожидаемым\n"
                mv -f "$tmp_file" "$dest_file"
                success=0
                break
            else
                # Проверка не прошла
                case "$_last_error" in
                    size_mismatch)
                        printf "  ${red}Ошибка${reset}: Размер загруженного файла (%s байт) не соответствует ожидаемому (%s байт)\n" "$_last_size" "$expected_size"
                        printf "  Файл повреждён или загружен не полностью. Повторная попытка...\n"
                        ;;
                    *)
                        printf "  ${red}Ошибка${reset}: %s\n" "$_last_error"
                        ;;
                esac
                rm -f "$tmp_file"
            fi
        fi

        # Если попытка сорвалась и она НЕ последняя — ждем и повторяем
        if [ "$attempt" -lt "$max_attempts" ]; then
            printf "  ${yellow}Предупреждение${reset}: Попытка %d не удалась. Повтор через %d сек...\n" "$attempt" "$delay"
            sleep "$delay"
        fi

        attempt=$((attempt + 1))
    done

    # Если все попытки исчерпаны и загрузка не удалась
    if [ "$success" -ne 0 ]; then
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
            size|size_mismatch)
                printf "  ${red}Ошибка${reset}: размер файла не соответствует ожидаемому (%s байт)\n  Оставляем старый файл\n\n" "$_last_size"
                ;;
            *)
                if [ "$max_attempts" -gt 1 ]; then
                    printf "  ${red}Ошибка${reset}: не удалось загрузить %s после %d попыток\n\n" "$display_name" "$max_attempts"
                else
                    printf "  ${red}Ошибка${reset}: не удалось загрузить %s\n\n" "$display_name"
                fi
                ;;
        esac
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

install_geoipset() {
    local action="$1"

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