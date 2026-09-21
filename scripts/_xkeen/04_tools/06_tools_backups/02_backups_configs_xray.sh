# Создание резервной копии конфигурации Xray
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

# Восстановление конфигурации Xray из резервной копии
restore_backup_configs_xray() {
    latest_backup=""

    for entry in "$backups_dir"/*_configs_xray; do
        if [ -e "$entry" ]; then
            latest_backup="$entry"
        fi
    done

    if [ -n "$latest_backup" ]; then
        # Копируем бэкап во временную директорию рядом с целевой и заменяем
        # текущую конфигурацию только при успешном копировании, чтобы сбой
        # cp -r (диск заполнен, обрыв сессии) не оставил xray_conf_dir пустой
        restore_tmp_dir="${xray_conf_dir}.restore_tmp"
        rm -rf "${restore_tmp_dir:?}"
        mkdir -p "$restore_tmp_dir"

        if cp -r "$latest_backup"/* "$restore_tmp_dir/"; then
            rm -rf "${xray_conf_dir:?}"
            mv "$restore_tmp_dir" "$xray_conf_dir"
            echo -e "  Конфигурация Xray ${green}успешно восстановлена${reset} из: $(basename "$latest_backup")"
        else
            rm -rf "${restore_tmp_dir:?}"
            echo -e "  ${red}Ошибка${reset} при восстановлении файлов"
        fi
    else
        echo -e "  ${red}Ошибка:${reset} Резервные копии не найдены в $backups_dir"
    fi
}
