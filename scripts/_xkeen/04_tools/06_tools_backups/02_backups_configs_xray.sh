backup_configs_xray() {
    backup_filename="${current_datetime}_configs_xray"
    backup_configs_dir="$backups_dir/$backup_filename"
    mkdir -p "$backup_configs_dir"

    if cp -r "$xray_conf_dir"/* "$backup_configs_dir/"; then
        echo -e "  Резервная копия конфигурации Xray создана: ${yellow}$backup_filename${reset}"
    else
        echo -e "  ${red}Ошибка${reset} при создании резервной копии конфигураций Xray"
    fi
}

restore_backup_configs_xray() {
    latest_backup=""

    for entry in "$backups_dir"/*_configs_xray; do
        if [ -e "$entry" ]; then
            latest_backup="$entry"
        fi
    done

    if [ -n "$latest_backup" ]; then
        rm -rf "${xray_conf_dir:?}"/*

        if cp -r "$latest_backup"/* "$xray_conf_dir/"; then
            echo -e "  Конфигурация Xray ${green}успешно восстановлена${reset} из: $(basename "$latest_backup")"
        else
            echo -e "  ${red}Ошибка${reset} при восстановлении файлов"
        fi
    else
        echo -e "  ${red}Ошибка:${reset} Резервные копии не найдены в $backups_dir"
    fi
}