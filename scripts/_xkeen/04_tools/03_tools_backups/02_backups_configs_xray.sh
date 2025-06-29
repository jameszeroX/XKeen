backup_configs_xray() {
    backup_filename="${current_datetime}_configs_xray"
    backup_configs_dir="$backups_dir/$backup_filename"
    mkdir -p "$backup_configs_dir"

    # Резервное копирование всех файлов конфигурации Xray
    cp -r "$install_conf_dir"/* "$backup_configs_dir/"

    if [ $? -eq 0 ]; then
        echo -e "  Резервная копия конфигурации Xray создана: ${yellow}$backup_filename${reset}"
    else
        echo -e "  ${red}Ошибка${reset} при создании резервной копии конфигураций Xray"
    fi
}

restore_backup_configs_xray() {
    # Найти последнюю резервную копию конфигурации Xray
    latest_backup=$(ls -t "$backups_dir" | grep "configs_xray" | head -n 1)

    if [ -n "$latest_backup" ]; then
        backup_path="$backups_dir/$latest_backup"
		
        rm -rf "$install_conf_dir"/*
        cp -r "$backup_path"/* "$install_conf_dir/"

        echo -e "  Конфигурация Xray ${green}успешно восстановлена${reset}"
    fi
}
