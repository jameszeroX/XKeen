# Создание резервной копии конфигурации Mihomo
backup_configs_mihomo() {
    backup_filename="${current_datetime}_configs_mihomo"
    backup_configs_dir="$backups_dir/$backup_filename"
    mkdir -p "$backups_dir" || return 1
    backup_tmp_dir=$(mktemp -d "$backups_dir/.backup-XXXXXX") || return 1

    if cp -r "$mihomo_conf_dir"/. "$backup_tmp_dir/" &&
       [ ! -e "$backup_configs_dir" ] &&
       mv "$backup_tmp_dir" "$backup_configs_dir"; then
        echo -e "  Резервная копия конфигурации Mihomo создана: ${yellow}$backup_filename${reset}"
    else
        rm -rf "${backup_tmp_dir:?}"
        echo -e "  ${red}Ошибка${reset} при создании резервной копии конфигураций Mihomo"
        return 1
    fi
}

# Восстановление конфигурации Mihomo из резервной копии
_restore_config_tree_mihomo() {
    _rctm_source="$1"
    _rctm_target="$2"
    if [ -z "$_rctm_target" ] || [ "$_rctm_target" = / ]; then
        echo -e "  ${red}Ошибка${reset}: недопустимый путь конфигурации Mihomo"
        return 1
    fi
    _rctm_stage=$(mktemp -d "${_rctm_target}.restore-XXXXXX") || {
        echo -e "  ${red}Ошибка${reset}: не удалось подготовить восстановление Mihomo"
        return 1
    }

    if ! cp -r "$_rctm_source"/. "$_rctm_stage/"; then
        rm -rf "${_rctm_stage:?}"
        echo -e "  ${red}Ошибка${reset} при копировании резервной копии Mihomo"
        return 1
    fi

    _rctm_previous=$(mktemp -d "${_rctm_target}.previous-XXXXXX") || {
        rm -rf "${_rctm_stage:?}"
        echo -e "  ${red}Ошибка${reset}: не удалось подготовить откат Mihomo"
        return 1
    }
    _rctm_had_target=false
    if [ -e "$_rctm_target" ] || [ -L "$_rctm_target" ]; then
        if ! mv "$_rctm_target" "$_rctm_previous/"; then
            rm -rf "${_rctm_stage:?}" "${_rctm_previous:?}"
            echo -e "  ${red}Ошибка${reset}: не удалось сохранить текущую конфигурацию Mihomo"
            return 1
        fi
        _rctm_had_target=true
    fi

    if mv "$_rctm_stage" "$_rctm_target"; then
        if ! rm -rf "${_rctm_previous:?}"; then
            echo -e "  ${yellow}Предупреждение${reset}: старая конфигурация Mihomo осталась в $_rctm_previous"
        fi
        echo -e "  Конфигурация Mihomo ${green}успешно восстановлена${reset}"
        return 0
    fi

    if [ "$_rctm_had_target" = true ]; then
        _rctm_name=$(basename "$_rctm_target")
        if ! mv "$_rctm_previous/$_rctm_name" "$_rctm_target"; then
            rm -rf "${_rctm_stage:?}"
            echo -e "  ${red}Ошибка${reset}: сбой восстановления Mihomo; прежняя конфигурация сохранена в $_rctm_previous"
            return 1
        fi
    fi
    rm -rf "${_rctm_stage:?}" "${_rctm_previous:?}"
    echo -e "  ${red}Ошибка${reset} при публикации конфигурации Mihomo"
    return 1
}

restore_backup_configs_mihomo() {
    latest_backup=""

    for entry in "$backups_dir"/*_configs_mihomo; do
        if [ -e "$entry" ]; then
            latest_backup="$entry"
        fi
    done

    if [ -n "$latest_backup" ]; then
        _restore_config_tree_mihomo "$latest_backup" "$mihomo_conf_dir"
    else
        echo -e "  ${red}Ошибка:${reset} Резервные копии не найдены в $backups_dir"
        return 1
    fi
}
