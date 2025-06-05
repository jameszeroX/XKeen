# Удаление временных файлов и директорий
delete_tmp() {
    if [ -d "$tmp_dir_global/xkeen" ]; then
        rm -r "$tmp_dir_global/xkeen"
    fi

    if [ -f "$cron_dir/root.tmp" ]; then
        rm "$cron_dir/root.tmp"
    fi
	
    if [ -f "/opt/etc/ndm/netfilter.d/proxy.sh" ]; then
        rm "/opt/etc/ndm/netfilter.d/proxy.sh"
    fi
	
	echo -e "  Выполняется ${yellow}очистка временных файлов${reset}"
	sleep 1
	echo -e "  Очистка временных файлов ${green}выполнена${reset}"
}
