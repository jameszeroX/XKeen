# Определение статуса для задач cron
get_existing_cron_time() {
    crontab -l 2>/dev/null | grep 'xkeen -ug' | head -n1 | awk '{print $1,$2,$3,$4,$5}'
}

format_cron_time() {
    cron="$1"

    minute=$(echo "$cron" | awk '{print $1}')
    hour=$(echo "$cron" | awk '{print $2}')
    dow=$(echo "$cron" | awk '{print $5}')

    formatted_hour=$(printf "%02d" "$hour")
    formatted_minute=$(printf "%02d" "$minute")

    case "$dow" in
        "*") day="Ежедневно" ;;
        1) day="Понедельник" ;;
        2) day="Вторник" ;;
        3) day="Среда" ;;
        4) day="Четверг" ;;
        5) day="Пятница" ;;
        6) day="Суббота" ;;
        0) day="Воскресенье" ;;
        *) day="Неизвестно" ;;
    esac

    echo "$day в $formatted_hour:$formatted_minute"
}

choice_update_cron() {
    has_updatable_cron_tasks=false
    [ "$info_update_geofile_cron" = "installed" ] && has_updatable_cron_tasks=true

    existing_cron=$(get_existing_cron_time)
    
    if [ -n "$existing_cron" ]; then
        echo
        echo -e "  Время обновления ${yellow}геофайлов${reset} установлено на: ${green}$(format_cron_time "$existing_cron")${reset}"
    fi

    while true; do
        choice_canel_cron_select=false
        choice_geofile_cron_select=false
        choice_delete_all_cron_select=false
        invalid_choice=false

        echo
        echo -e "  Выберите номер действия для автообновления ${yellow}GeoFile/GeoIPSET${reset}"
        echo

        [ "$info_update_geofile_cron" != "installed" ] && geofile_choice="Включить" || geofile_choice="Обновить"
        echo "     1. $geofile_choice задачу"
        echo "     0. Пропустить"

        [ "$has_updatable_cron_tasks" = true ] && echo && echo "     2. Выключить автообновление"
        echo

        while true; do
            read -r -p "  Ваш выбор: " update_choices
            update_choices=$(echo "$update_choices" | sed 's/,/, /g')

            if echo "$update_choices" | grep -qE '^[0-2]$'; then
                break
            else
                echo -e "  ${red}Некорректный ввод.${reset} Выберите один из предложенных вариантов"
            fi
        done

        for choice in $update_choices; do
            case "$choice" in
                1)
                    choice_geofile_cron_select=true
                    if [ "$info_update_geofile_cron" = "installed" ]; then
                        echo -e "  ${yellow}Будет выполнено${reset} обновление задачи GeoFile/GeoIPSET"
                    else
                        echo -e "  ${yellow}Будет выполнено${reset} включение задачи GeoFile/GeoIPSET"
                    fi
                    ;;
                0)
                    choice_canel_cron_select=true
                    echo "  Выполнен пропуск настройки автообновления"
                    return
                    ;;
                2)
                    if [ "$has_updatable_cron_tasks" = true ]; then
                        delete_cron_geofile
                        echo -e "  Автообновление баз GeoFile/GeoIPSET ${green}выключено${reset}"
                    else
                        echo -e "  ${red}Автообновление баз GeoFile/GeoIPSET не включено${reset}. Выберите другой пункт"
                        invalid_choice=true
                    fi
                    ;;
                *)
                    echo -e "  ${red}Некорректный ввод${reset}"
                    invalid_choice=true
                    ;;
            esac
        done

        [ "$invalid_choice" = true ] || break
    done
}
