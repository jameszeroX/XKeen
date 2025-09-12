data_is_updated_exclude() {
    file="$1"
    new_delay="$2"
    current_delay=$(
        awk -F= '/start_delay/{print $2; exit}' "$file" \
        | tr -d '"'
    )
    if [ "$current_delay" = "$new_delay" ]; then
        return 0
    else
        return 1
    fi
}

delay_autostart() {
    new_delay="$1"
    target_file=""

    if [ -f "$initd_dir/S99xkeen" ]; then
        target_file="$initd_dir/S99xkeen"
    else
        echo -e "  ${red}Ошибка${reset}: Не найден файл автозапуска S99xkeen"
        return 1
    fi

    # Вывод текущей задержки автозапуска
    if [ -z "$new_delay" ]; then
        current_delay=$(
            awk -F= '/start_delay/{print $2; exit}' "$target_file" \
            | tr -d '[:space:]'
        )
        current_delay=${current_delay:-""}
        echo -e "  Текущая задержка автозапуска XKeen ${yellow}$current_delay секунд(ы)${reset}"
        return 1
    fi

    # Проверка, что new_delay - это число
    if ! [ "$new_delay" -eq "$new_delay" ] 2>/dev/null; then
        echo -e "  ${red}Ошибка${reset}"
        echo "  Новая задержка должна быть числом"
        return 1
    fi

    current_delay=$(
        awk -F= '/start_delay/{print $2; exit}' "$target_file" \
        | tr -d '[:space:]'
    )
    current_delay=${current_delay:-""}

    if [ "$current_delay" = "$new_delay" ]; then
        echo "  Обновление задержки автозапуска XKeen не требуется"
        return 0
    else
        tmpfile=$(mktemp)
        awk -v new_delay="start_delay=$new_delay" 'BEGIN{replaced=0} /start_delay/ && !replaced {sub(/start_delay=[^ ]*/, new_delay); replaced=1} {print}' "$target_file" > "$tmpfile" && mv "$tmpfile" "$target_file"
    fi

    while true; do
        if data_is_updated_exclude "$target_file" "$new_delay"; then
            echo -e "  ${green}Успех${reset}"
            echo -e "  Установлена задержка автозапуска XKeen ${yellow}${new_delay} секунд(ы)${reset}"
            break
        fi
    done
}