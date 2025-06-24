
# Создание резервной копии XKeen
backup_xkeen() {
    backup_dir="${backups_dir}/${current_datetime}_xkeen_v${xkeen_current_version}"
    mkdir -p "$backup_dir"

    # Копирование конфигурации и файлов XKeen в резервную копию
    cp -r "$install_dir/.xkeen" "$install_dir/xkeen" "$backup_dir/"

    # Переименование скрытой директории .xkeen в _xkeen в резервной копии
    mv "$backup_dir/.xkeen" "$backup_dir/_xkeen"

    if [ -s "$backup_dir/xkeen" ]; then
        echo -e "  Резервная копия XKeen создана: ${yellow}${current_datetime}_xkeen_v${xkeen_current_version}${reset}"
    else
        echo -e "  ${red}Ошибка при создании резервной копии XKeen${reset}"
    fi
}

# Восстановление XKeen из резервной копии
restore_backup_xkeen() {
    restore_script=$(mktemp)
    cat <<eof > "$restore_script"
#!/bin/sh

latest_backup_dir=\$(ls -t -d "$backups_dir"/*xkeen* | head -n 1)

if [ -n "\$latest_backup_dir" ]; then
    cp -r "\$latest_backup_dir"/_xkeen "$install_dir/"
    if [ \$? -eq 0 ]; then
        cp -f "\$latest_backup_dir"/xkeen "$install_dir/"
        if [ \$? -eq 0 ]; then
            if [ -d "$install_dir/_xkeen" ]; then
                if [ -d "$install_dir/.xkeen" ]; then
                    rm -rf "$install_dir/.xkeen"
                fi
                mv "$install_dir/_xkeen" "$install_dir/.xkeen"
                echo "  Резервная копия XKeen успешно восстановлена"
            fi
        else
            echo "  Не удалось скопировать _xkeen"
        fi
    else
        echo "  Не удалось скопировать _xkeen"
    fi
else
    echo "  Подходящая резервная копия XKeen не найдена"
fi

# Удаление временного скрипта
rm "\$0"
eof

    chmod +x "$restore_script"
    "$restore_script"
}
