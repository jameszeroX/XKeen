# Определение статуса для задач cron

choice_update_cron() {
    has_updatable_cron_tasks=false
    [ "$info_update_geofile_cron" = "installed" ] && has_updatable_cron_tasks=true

    while true; do
        choice_canel_cron_select=false
        choice_geofile_cron_select=false
        choice_delete_all_cron_select=false
        invalid_choice=false

        echo
        echo -e "  ${yellow}Выберите номер действия${reset} для автообновления GeoFile"
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
                        echo -e "  ${yellow}Будет выполнено${reset} обновление задачи GeoFile"
                    else
                        echo -e "  ${yellow}Будет выполнено${reset} включение задачи GeoFile"
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
                        echo -e "  Автообновление баз GeoFile ${green}выключено${reset}"
                    else
                        echo -e "  ${red}Автообновление баз GeoFile не включено${reset}. Выберите другой пункт"
                        invalid_choice=true
                    fi
                    ;;
                *)
                    echo -e "  ${red}Некорректный ввод{reset}"
                    invalid_choice=true
                    ;;
            esac
        done

        [ "$invalid_choice" = true ] || break
    done
}
