backup_configs_mihomo() {
    backup_filename="${current_datetime}_configs_mihomo"
    backup_configs_dir="$backups_dir/$backup_filename"
    mkdir -p "$backup_configs_dir"

    # Резервное копирование всех файлов конфигурации Mihomo
    cp -r "$mihomo_conf_dir"/* "$backup_configs_dir/"

    if [ $? -eq 0 ]; then
        echo -e "  Резервная копия конфигурации Mihomo создана: ${yellow}$backup_filename${reset}"
    else
        echo -e "  ${red}Ошибка${reset} при создании резервной копии конфигураций Mihomo"
    fi
}

restore_backup_configs_mihomo() {
    # Найти последнюю резервную копию конфигурации Mihomo
    latest_backup=$(ls -t "$backups_dir" | grep "configs_mihomo" | head -n 1)

    if [ -n "$latest_backup" ]; then
        backup_path="$backups_dir/$latest_backup"
		
        rm -rf "$mihomo_conf_dir"/*
        cp -r "$backup_path"/* "$mihomo_conf_dir/"

        echo -e "  Конфигурация Mihomo ${green}успешно восстановлена${reset}"
    fi
}
