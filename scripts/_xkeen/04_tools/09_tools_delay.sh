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

update_start_delay() {
    new_delay="$1"

    # Проверка, что new_delay не пусто
    if [ -z "$new_delay" ]; then
        #echo -e "  ${red}Ошибка${reset}"
		#echo "  Новая задержка не может быть пустой"
        return 1
    fi

    # Проверка, что new_delay - это число
    if ! [ "$new_delay" -eq "$new_delay" ] 2>/dev/null; then
        #echo -e "  ${red}Ошибка${reset}"
		#echo "  Новая задержка должна быть числом"
        return 1
    fi

    current_delay=$(
        awk -F= '/start_delay/{print $2; exit}' "$initd_dir/S24xray" \
        | tr -d '[:space:]'
    )
    current_delay=${current_delay:-""}

    tmpfile=$(mktemp)
    awk -v new_delay="start_delay=$new_delay" 'BEGIN{replaced=0} /start_delay/ && !replaced {sub(/start_delay=[^ ]*/, new_delay); replaced=1} {print}' "$initd_dir/S24xray" > "$tmpfile" && mv "$tmpfile" "$initd_dir/S24xray"

    while true; do
        if data_is_updated_exclude "$initd_dir/S24xray" "$new_delay"; then
            break
        fi
    done

    #echo -e "  ${green}Успех${reset}"
	#echo -e "  Стартовая задержка запуска обновлена до ${new_delay} секунд(ы)"
}

delay_autostart() {
    new_delay="$1"

    # Проверка, что new_delay не пусто
    if [ -z "$new_delay" ]; then
        echo -e "  ${red}Ошибка${reset}"
		echo "  Новая задержка не может быть пустой"
        return 1
    fi

    # Проверка, что new_delay - это число
    if ! [ "$new_delay" -eq "$new_delay" ] 2>/dev/null; then
        echo -e "  ${red}Ошибка${reset}"
		echo "  Новая задержка должна быть числом"
        return 1
    fi

    current_delay=$(
        awk -F= '/start_delay/{print $2; exit}' "$initd_dir/S99xkeenstart" \
        | tr -d '[:space:]'
    )
    current_delay=${current_delay:-""}

    if [ "$current_delay" = "$new_delay" ]; then
        echo "  Обновление задержки автозапуска XKeen не требуется"
        return 0
    else

    tmpfile=$(mktemp)
    awk -v new_delay="start_delay=$new_delay" 'BEGIN{replaced=0} /start_delay/ && !replaced {sub(/start_delay=[^ ]*/, new_delay); replaced=1} {print}' "$initd_dir/S99xkeenstart" > "$tmpfile" && mv "$tmpfile" "$initd_dir/S99xkeenstart"

    fi

    while true; do
        if data_is_updated_exclude "$initd_dir/S99xkeenstart" "$new_delay"; then
        echo -e "  ${green}Успех${reset}"
        echo -e "  Установлена задержка автозапуска XKeen - ${new_delay} секунд(ы)"
            break
        fi
    done
}