# Определение статуса для задач cron

choose_update_cron() {
    has_updatable_cron_tasks=false
    [ "$info_update_geofile_cron" = "installed" ] && has_updatable_cron_tasks=true

    while true; do
        # Сброс флагов при каждом повторении цикла
        chose_canel_cron_select=false
        chose_geofile_cron_select=false
        chose_delete_all_cron_select=false
        invalid_choice=false

        echo
        echo
        echo -e "  ${yellow}Выберите номер действия${reset} для автообновления GeoFile"
        echo

        [ "$info_update_geofile_cron" != "installed" ] && geofile_choice="Включить" || geofile_choice="Обновить"

        echo "     1. $geofile_choice задачу"
        echo "     0. Пропустить"
        echo
        [ "$has_updatable_cron_tasks" = true ] && echo "     99. Выключить автообновление"
        echo

        update_choices=$(input_digits "Ваш выбор: " "${red}Некорректный номер действия. ${reset}Пожалуйста, выберите снова")

        for choice in $update_choices; do
            if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
                echo -e "  ${red}Некорректный номер действия.${reset} Пожалуйста, выберите снова"
                invalid_choice=true
                sleep 1
                break
            fi
        done

        [ "$invalid_choice" = true ] && continue

        for choice in $update_choices; do
            case "$choice" in
                1)
                    if [ "$info_update_geofile_cron" = "installed" ]; then
                        chose_geofile_cron_select=true
                        echo -e "  ${yellow}Будет выполнено${reset} обновление задачи GeoFile"
                    else
                        chose_geofile_cron_select=true
                        echo -e "  ${yellow}Будет выполнено${reset} включение задачи GeoFile"
                    fi
                    ;;
                0)
                    chose_canel_cron_select=true
                    echo "  Выполнен пропуск настройки автообновления"
                    return
                    ;;
                99)
                    if [ "$has_updatable_cron_tasks" = true ]; then
                        chose_delete_all_cron_select=true
                        echo "  Будет выключено автообновление GeoFile"
                    else
                        echo -e "  ${red}Автообновление GeoFile не включено${reset}. Выберите другой пункт"
                        invalid_choice=true
                    fi
                    ;;
                *)
                    echo -e "  ${red}Некорректный номер действия: $choice${reset}. Пожалуйста, выберите снова"
                    invalid_choice=true
                    ;;
            esac
        done

        [ "$invalid_choice" = true ] && continue

        break
    done
}