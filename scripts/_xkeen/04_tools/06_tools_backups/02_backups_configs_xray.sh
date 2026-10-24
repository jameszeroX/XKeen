# Создание резервной копии конфигурации Xray
backup_configs_xray() {
    backup_filename="${current_datetime}_configs_xray"
    backup_configs_dir="$backups_dir/$backup_filename"
    mkdir -p "$backups_dir" || return 1
    backup_tmp_dir=$(mktemp -d "$backups_dir/.backup-XXXXXX") || return 1

    if cp -r "$xray_conf_dir"/. "$backup_tmp_dir/" &&
       [ ! -e "$backup_configs_dir" ] &&
       mv "$backup_tmp_dir" "$backup_configs_dir"; then
        echo -e "  Резервная копия конфигурации Xray создана: ${yellow}$backup_filename${reset}"
    else
        rm -rf "${backup_tmp_dir:?}"
        echo -e "  ${red}Ошибка${reset} при создании резервной копии конфигураций Xray"
        return 1
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
