# Создание резервной копии XKeen
backup_xkeen() {
    if choice_backup_xkeen && [ -z "$manual_backup" ]; then
        return 0
    fi

    backup_filename="${current_datetime}_xkeen_v${xkeen_current_version}"
    backup_dir="${backups_dir}/${backup_filename}"
    mkdir -p "$backups_dir" || return 1
    backup_tmp_dir=$(mktemp -d "$backups_dir/.backup-XXXXXX") || return 1

    # Копирование файлов. Проверяем успех всей операции копирования
    if cp -r "$install_dir/.xkeen" "$install_dir/xkeen" "$backup_tmp_dir/"; then
        # Переименование скрытой директории для удобства хранения
        if ! mv "$backup_tmp_dir/.xkeen" "$backup_tmp_dir/_xkeen" ||
           [ -e "$backup_dir" ] || ! mv "$backup_tmp_dir" "$backup_dir"; then
            rm -rf "${backup_tmp_dir:?}"
            echo -e "  ${red}Ошибка${reset} при создании резервной копии XKeen"
            return 1
        fi
        echo -e "  Резервная копия XKeen создана: ${yellow}${backup_filename}${reset}"
    else
        rm -rf "${backup_tmp_dir:?}"
        echo -e "  ${red}Ошибка${reset} при создании резервной копии XKeen"
        return 1
    fi
}

# Восстановление XKeen из резервной копии
restore_backup_xkeen() {
    latest_backup_dir=""

    for entry in "$backups_dir"/*xkeen*; do
        if [ -d "$entry" ]; then
            latest_backup_dir="$entry"
        fi
    done

    if [ -n "$latest_backup_dir" ]; then
        # Используем временную директорию для безопасности при восстановлении
        # Чтобы не удалить старый .xkeen, пока не убедимся, что копия цела

        if cp -r "$latest_backup_dir/_xkeen" "$install_dir/" && \
           cp -f "$latest_backup_dir/xkeen" "$install_dir/"; then

            rm -rf "${install_dir:?}/.xkeen"
            mv "$install_dir/_xkeen" "$install_dir/.xkeen"
            
            echo -e "  XKeen ${green}успешно восстановлен${reset} из: $(basename "$latest_backup_dir")"
        else
            rm -rf "${install_dir:?}/_xkeen"
            echo -e "  ${red}Ошибка:${reset} Не удалось скопировать файлы из резервной копии"
        fi
    else
        echo -e "  ${red}Ошибка:${reset} Подходящая резервная копия XKeen не найдена"
    fi
}
