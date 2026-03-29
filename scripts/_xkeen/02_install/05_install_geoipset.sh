# Функция для установки и обновления GeoIPSET
install_geoipset_lst() {
    mkdir -p "$ipset_cfg" || { echo "Ошибка: Не удалось создать директорию $ipset_cfg"; exit 1; }

    url="$1"
    dest_file="$2"
    display_name="$3"
    ip_type="$4"

    temp_file=$(mktemp)
    printf "  Загрузка %s...\n" "$display_name"

    if [ "$use_direct" = "true" ]; then
        fetch_url="$url"
    else
        fetch_url="$gh_proxy/$url"
    fi

    curl --connect-timeout 10 $curl_timeout -fL -o "$temp_file" "$fetch_url" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        rm -f "$temp_file"
        printf "  ${red}Ошибка${reset}: не удалось загрузить %s\n\n" "$display_name"
        return 1
    fi

    # Проверка на HTML-страницу заглушку
    if grep -qi "<html" "$temp_file"; then
        rm -f "$temp_file"
        printf "  ${red}Ошибка${reset}: получена HTML-страница вместо списка IP\n  Оставляем старый файл\n\n"
        return 1
    fi

    # Валидация
    if [ "$ip_type" = "ipv4" ] && ! grep -q "^[0-9]" "$temp_file"; then
        rm -f "$temp_file"
        printf "  ${red}Ошибка${reset}: %s не содержит корректных IPv4-адресов\n  Оставляем старый файл\n\n" "$display_name"
        return 1
        elif [ "$ip_type" = "ipv6" ] && ! grep -q ":" "$temp_file"; then
        rm -f "$temp_file"
        printf "  ${red}Ошибка${reset}: %s не содержит корректных IPv6-адресов\n  Оставляем старый файл\n\n" "$display_name"
        return 1
    fi

    [ "$action" = "init" ] && msg_geoipset="установлен" || msg_geoipset="обновлён"
    mv -f "$temp_file" "$dest_file"
    printf "  %s ${green}успешно $msg_geoipset${reset}\n\n" "$display_name"
    return 0
}

load_geoipset() {
    set="$1"
    file="$2"
    family="$3"

    ipset create "$set" hash:net family "$family" -exist
    ipset flush "$set"

    [ -f "$file" ] && awk '/^[0-9a-fA-F]/ {print "add '"$set"' "$1}' "$file" | ipset restore -exist
}

install_geoipset() {
    action="$1"

    if [ "$action" = "init" ]; then
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

    if ip -4 addr show 2>/dev/null | grep -q "inet " && command -v iptables >/dev/null 2>&1; then
        [ "$action" != "init" ] && [ ! -f "$ru_exclude_ipv4" ] && return 0
        install_geoipset_lst "$geoipv4_url" "$ru_exclude_ipv4" "IPv4 (IPSet)" "ipv4"
        load_geoipset geo_exclude "$ru_exclude_ipv4" inet
    fi

    if ip -6 addr show 2>/dev/null | grep -q "inet6 " && command -v ip6tables >/dev/null 2>&1; then
        [ "$action" != "init" ] && [ ! -f "$ru_exclude_ipv6" ] && return 0
        install_geoipset_lst "$geoipv6_url" "$ru_exclude_ipv6" "IPv6 (IPSet)" "ipv6"
        load_geoipset geo_exclude6 "$ru_exclude_ipv6" inet6
    fi
}