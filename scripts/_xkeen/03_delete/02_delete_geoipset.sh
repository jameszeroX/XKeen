# Функция для удаления GeoIPSET
delete_geoipset() {
    while true; do
        printf "\n  Желаете удалить российские IP-адреса из исключений проксирования?\n\n"
        printf "     1. Да. Загруженные файлы подсетей будут удалены, а списки очищены\n"
        printf "     0. Нет. Отмена удаления\n\n"
        printf "  Ваш выбор: "
        read -r choice
        
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

    ipset flush geo_exclude 2>/dev/null
    ipset flush geo_exclude6 2>/dev/null

    [ -f "$ru_exclude_ipv4" ] && rm -f "$ru_exclude_ipv4" 2>/dev/null
    [ -f "$ru_exclude_ipv6" ] && rm -f "$ru_exclude_ipv6" 2>/dev/null
    # [ -d "$ipset_cfg" ] && rm -rf "$ipset_cfg"

    printf "  Списки исключений GeoIPSET ${green}успешно удалены${reset}\n\n"
    return 0
}

delete_geoipset_key() {
    ipset flush geo_exclude 2>/dev/null
    ipset flush geo_exclude6 2>/dev/null

    [ -f "$ru_exclude_ipv4" ] && rm -f "$ru_exclude_ipv4" 2>/dev/null
    [ -f "$ru_exclude_ipv6" ] && rm -f "$ru_exclude_ipv6" 2>/dev/null
    # [ -d "$ipset_cfg" ] && rm -rf "$ipset_cfg"
}