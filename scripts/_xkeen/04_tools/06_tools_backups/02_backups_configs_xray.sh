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
_restore_config_tree_xray() {
    _rctx_source="$1"
    _rctx_target="$2"
    if [ -z "$_rctx_target" ] || [ "$_rctx_target" = / ]; then
        echo -e "  ${red}Ошибка${reset}: недопустимый путь конфигурации Xray"
        return 1
    fi
    _rctx_stage=$(mktemp -d "${_rctx_target}.restore-XXXXXX") || {
        echo -e "  ${red}Ошибка${reset}: не удалось подготовить восстановление Xray"
        return 1
    }

    if ! cp -r "$_rctx_source"/. "$_rctx_stage/"; then
        rm -rf "${_rctx_stage:?}"
        echo -e "  ${red}Ошибка${reset} при копировании резервной копии Xray"
        return 1
    fi

    _rctx_previous=$(mktemp -d "${_rctx_target}.previous-XXXXXX") || {
        rm -rf "${_rctx_stage:?}"
        echo -e "  ${red}Ошибка${reset}: не удалось подготовить откат Xray"
        return 1
    }
    _rctx_had_target=false
    if [ -e "$_rctx_target" ] || [ -L "$_rctx_target" ]; then
        if ! mv "$_rctx_target" "$_rctx_previous/"; then
            rm -rf "${_rctx_stage:?}" "${_rctx_previous:?}"
            echo -e "  ${red}Ошибка${reset}: не удалось сохранить текущую конфигурацию Xray"
            return 1
        fi
        _rctx_had_target=true
    fi

    if mv "$_rctx_stage" "$_rctx_target"; then
        if ! rm -rf "${_rctx_previous:?}"; then
            echo -e "  ${yellow}Предупреждение${reset}: старая конфигурация Xray осталась в $_rctx_previous"
        fi
        echo -e "  Конфигурация Xray ${green}успешно восстановлена${reset}"
        return 0
    fi

    if [ "$_rctx_had_target" = true ]; then
        _rctx_name=$(basename "$_rctx_target")
        if ! mv "$_rctx_previous/$_rctx_name" "$_rctx_target"; then
            rm -rf "${_rctx_stage:?}"
            echo -e "  ${red}Ошибка${reset}: сбой восстановления Xray; прежняя конфигурация сохранена в $_rctx_previous"
            return 1
        fi
    fi
    rm -rf "${_rctx_stage:?}" "${_rctx_previous:?}"
    echo -e "  ${red}Ошибка${reset} при публикации конфигурации Xray"
    return 1
}

restore_backup_configs_xray() {
    latest_backup=""

    for entry in "$backups_dir"/*_configs_xray; do
        if [ -e "$entry" ]; then
            latest_backup="$entry"
        fi
    done

    if [ -n "$latest_backup" ]; then
        _restore_config_tree_xray "$latest_backup" "$xray_conf_dir"
    else
        echo -e "  ${red}Ошибка:${reset} Резервные копии не найдены в $backups_dir"
        return 1
    fi
}
