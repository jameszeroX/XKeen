# Создание резервной копии XKeen
backup_xkeen() {
    if choice_backup_xkeen && [ -z "$manual_backup" ]; then
        return 0
    fi

    backup_dir="${backups_dir}/${current_datetime}_xkeen_v${xkeen_current_version}"
    mkdir -p "$backup_dir"

    # Копирование конфигурации и файлов XKeen в резервную копию
    cp -r "$install_dir/.xkeen" "$install_dir/xkeen" "$backup_dir/"

    # Переименование скрытой директории .xkeen в _xkeen в резервной копии
    mv "$backup_dir/.xkeen" "$backup_dir/_xkeen"

    if [ -s "$backup_dir/xkeen" ]; then
        echo -e "  Резервная копия XKeen создана: ${yellow}${current_datetime}_xkeen_v${xkeen_current_version}${reset}"
    else
        echo -e "  ${red}Ошибка${reset} при создании резервной копии XKeen"
    fi
}

# Восстановление XKeen из резервной копии
restore_backup_xkeen() {
    latest_backup_dir=$(ls -t -d "$backups_dir"/*xkeen* 2>/dev/null | head -n 1)

    if [ -n "$latest_backup_dir" ]; then
        if cp -r "$latest_backup_dir"/_xkeen "$install_dir/"; then
            if cp -f "$latest_backup_dir"/xkeen "$install_dir/"; then
                if [ -d "$install_dir/_xkeen" ]; then
                    if [ -d "$install_dir/.xkeen" ]; then
                        rm -rf "$install_dir/.xkeen"
                    fi
                    mv "$install_dir/_xkeen" "$install_dir/.xkeen"
                    echo -e "  XKeen ${green}успешно восстановлен${reset}"
                fi
            else
                echo "  Не удалось скопировать xkeen"
            fi
        else
            echo "  Не удалось скопировать _xkeen"
        fi
    else
        echo "  Подходящая резервная копия XKeen не найдена"
    fi
}
