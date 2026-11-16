# Функция для удаления GeoIPSET
delete_geoipset() {
    while true; do
        printf "\n  Желаете удалить российские IP-адреса из исключений проксирования?\n\n"
        printf "     1. Да. Загруженные файлы подсетей будут удалены, а списки очищены\n"
        printf "     0. Нет. Отмена удаления\n\n"
        printf "  Ваш выбор: "
        # Без TTY (cron, ssh без -t) read получает EOF: код возврата ненулевой,
        # choice остаётся пустым, попадает в ветку * — while true крутится
        # без блокировки на read, CPU-spin. Трактуем EOF как явный ввод 0.
        read -r choice || choice=0

        case "$choice" in
            0)
                echo
                printf "  Отмена удаления списков GeoIPSET.\n\n"
                return 0
                ;;
            1)
                echo
                break
                ;;
            *)
                printf "  Неверный ввод. Пожалуйста, введите 1 или 0.\n"
                ;;
        esac
    done

    if _delete_geoipset_resources; then
        printf "  Списки исключений GeoIPSET ${green}успешно удалены${reset}\n\n"
        return 0
    fi

    printf "  ${red}Не удалось полностью удалить списки исключений GeoIPSET${reset}\n\n"
    return 1
}

_delete_geoipset_resources() {
    local failed=false
    local set
    local set_names
    local set_entries
    local file

    if ! set_names=$(ipset list -name 2>/dev/null); then
        failed=true
        set_names=''
    else
        set_names=$(printf '%s\n' "$set_names" | tr '\n' ' ')
    fi

    for set in geo_exclude geo_exclude6; do
        case " $set_names " in
            *" $set "*)
                if ! ipset flush "$set" 2>/dev/null; then
                    failed=true
                elif ! set_entries=$(ipset save "$set" 2>/dev/null); then
                    failed=true
                elif printf '%s\n' "$set_entries" | grep -F "add $set " >/dev/null 2>&1; then
                    failed=true
                fi
                ;;
        esac
    done

    for file in "$ru_exclude_ipv4" "$ru_exclude_ipv6"; do
        if { [ -e "$file" ] || [ -L "$file" ]; } &&
            { ! rm -f "$file" 2>/dev/null || [ -e "$file" ] || [ -L "$file" ]; }; then
            failed=true
        fi
    done

    [ "$failed" = false ]
}

delete_geoipset_key() {
    _delete_geoipset_resources
}
