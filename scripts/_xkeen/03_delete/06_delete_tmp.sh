# Удаление временных файлов и директорий
delete_tmp() {
    if [ -d "$tmp_dir_global/xkeen" ]; then
        rm -r "$tmp_dir_global/xkeen"
    fi

    if [ -f "$cron_dir/root.tmp" ]; then
        rm "$cron_dir/root.tmp"
    fi

    if ! pidof xray >/dev/null || ! pidof mihomo >/dev/null ; then
        if [ -f "/opt/etc/ndm/netfilter.d/proxy.sh" ]; then
            rm "/opt/etc/ndm/netfilter.d/proxy.sh"
        fi
    fi

    echo
    echo -e "  Очистка временных файлов ${green}выполнена${reset}"
}

delete_all() {
    echo
    echo -e "  Удалить резервные копии и пользовательские настройки?"
    echo -e "  ${yellow}$backups_dir${reset}"
    echo -e "  ${yellow}$xkeen_cfg${reset}"
    echo
    echo "     1. Да, удалить"
    echo "     0. Нет, оставить"
    echo

    while true; do
        read -r -p "  Ваш выбор: " choice
        case "$choice" in
            1)
                [ -d "$backups_dir" ] && rm -rf "$backups_dir"
                [ -d "$xkeen_cfg" ] && rm -rf "$xkeen_cfg"
                return 0
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "  ${red}Некорректный ввод${reset}"
                ;;
        esac
    done
}