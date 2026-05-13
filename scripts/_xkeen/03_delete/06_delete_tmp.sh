# Удаление временных файлов и директорий
delete_tmp() {
    [ -d "$ktmp_dir" ] && rm -rf "$ktmp_dir"
    [ -d "$xtmp_dir" ] && rm -rf "$xtmp_dir"
    [ -d "$mtmp_dir" ] && rm -rf "$mtmp_dir"
    [ -f "$cron_dir/root.tmp" ] && rm -f "$cron_dir/root.tmp"
    [ -f "$register_dir/new_entry.txt" ] && rm -f "$register_dir/new_entry.txt"
    [ -f "$install_dir/xray_bak" ] && rm -f "$install_dir/xray_bak"
    [ -f "$install_dir/mihomo_bak" ] && rm -f "$install_dir/mihomo_bak"
    [ -f "/tmp/xkrun" ] && rm -f "/tmp/xkrun"
    [ -f "/tmp/toff" ] && rm -f "/tmp/toff"

    if ! pidof xray >/dev/null && ! pidof mihomo >/dev/null ; then
        [ -f "$file_netfilter_hook" ] && rm "$file_netfilter_hook"
        [ -f "$file_schedule_hook" ] && rm "$file_schedule_hook"
        if command -v ipset >/dev/null 2>&1; then
            ipset flush "$name_ipset_deny_mac" >/dev/null 2>&1
            ipset destroy "$name_ipset_deny_mac" >/dev/null 2>&1
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