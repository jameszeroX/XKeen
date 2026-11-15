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
_rollback_xkeen_restore() {
    _rx_install="$1"
    _rx_stage="$2"
    _rx_previous="$3"
    _rx_failed=false

    if [ -e "$_rx_install/.xkeen" ] && ! mv "$_rx_install/.xkeen" "$_rx_stage/failed-modules"; then
        _rx_failed=true
    fi
    if [ -e "$_rx_install/xkeen" ] && ! mv "$_rx_install/xkeen" "$_rx_stage/failed-wrapper"; then
        _rx_failed=true
    fi
    if [ -e "$_rx_previous/.xkeen" ]; then
        if [ -e "$_rx_install/.xkeen" ] || ! mv "$_rx_previous/.xkeen" "$_rx_install/.xkeen"; then
            _rx_failed=true
        fi
    fi
    if [ -e "$_rx_previous/xkeen" ]; then
        if [ -e "$_rx_install/xkeen" ] || ! mv "$_rx_previous/xkeen" "$_rx_install/xkeen"; then
            _rx_failed=true
        fi
    fi

    if [ "$_rx_failed" = true ]; then
        echo -e "  ${red}Ошибка${reset}: откат XKeen не завершён; сохранённые копии находятся в $_rx_previous и $_rx_stage"
        return 1
    fi
    rm -rf "${_rx_previous:?}" "${_rx_stage:?}"
    return 0
}

restore_backup_xkeen() {
    latest_backup_dir=""

    for entry in "$backups_dir"/*xkeen*; do
        if [ -d "$entry" ]; then
            latest_backup_dir="$entry"
        fi
    done

    if [ -n "$latest_backup_dir" ]; then
        if [ -z "$install_dir" ] || [ "$install_dir" = / ]; then
            echo -e "  ${red}Ошибка:${reset} Недопустимый каталог установки XKeen"
            return 1
        fi

        _rx_stage=$(mktemp -d "$install_dir/.restore-XXXXXX") || {
            echo -e "  ${red}Ошибка${reset}: не удалось подготовить восстановление XKeen"
            return 1
        }
        if ! cp -r "$latest_backup_dir/_xkeen" "$_rx_stage/.xkeen" ||
           ! cp -p "$latest_backup_dir/xkeen" "$_rx_stage/xkeen" ||
           [ ! -d "$_rx_stage/.xkeen" ] || [ ! -f "$_rx_stage/xkeen" ]; then
            rm -rf "${_rx_stage:?}"
            echo -e "  ${red}Ошибка:${reset} Не удалось подготовить полную копию XKeen"
            return 1
        fi

        _rx_previous=$(mktemp -d "$install_dir/.restore-old-XXXXXX") || {
            rm -rf "${_rx_stage:?}"
            echo -e "  ${red}Ошибка${reset}: не удалось подготовить откат XKeen"
            return 1
        }
        if [ -e "$install_dir/xkeen" ] && ! mv "$install_dir/xkeen" "$_rx_previous/xkeen"; then
            rm -rf "${_rx_previous:?}" "${_rx_stage:?}"
            echo -e "  ${red}Ошибка${reset}: не удалось сохранить текущую оболочку XKeen"
            return 1
        fi
        if [ -e "$install_dir/.xkeen" ] && ! mv "$install_dir/.xkeen" "$_rx_previous/.xkeen"; then
            if [ -e "$_rx_previous/xkeen" ] && ! mv "$_rx_previous/xkeen" "$install_dir/xkeen"; then
                echo -e "  ${red}Ошибка${reset}: оболочка XKeen сохранена в $_rx_previous"
            else
                rm -rf "${_rx_previous:?}" "${_rx_stage:?}"
            fi
            echo -e "  ${red}Ошибка${reset}: не удалось сохранить текущие модули XKeen"
            return 1
        fi

        if ! mv "$_rx_stage/.xkeen" "$install_dir/.xkeen" ||
           ! mv "$_rx_stage/xkeen" "$install_dir/xkeen"; then
            _rollback_xkeen_restore "$install_dir" "$_rx_stage" "$_rx_previous"
            echo -e "  ${red}Ошибка:${reset} Не удалось опубликовать полную копию XKeen"
            return 1
        fi

        rm -rf "${_rx_previous:?}" "${_rx_stage:?}"
        echo -e "  XKeen ${green}успешно восстановлен${reset} из: $(basename "$latest_backup_dir")"
        return 0
    else
        echo -e "  ${red}Ошибка:${reset} Подходящая резервная копия XKeen не найдена"
        return 1
    fi
}
