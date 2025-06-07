# Функция для выбора вариантов GeoSite
choice_geosite() {
    has_missing_geosite_bases=false
    has_updatable_geosite_bases=false

    [ "$geo_exists_geosite_antifilter" != "installed" ] && has_missing_geosite_bases=true
    [ "$geo_exists_geosite_v2fly" != "installed" ] && has_missing_geosite_bases=true
    [ "$geo_exists_geosite_zkeen" != "installed" ] && has_missing_geosite_bases=true
    ([ "$geo_exists_geosite_antifilter" = "installed" ] || [ "$geo_exists_geosite_v2fly" = "installed" ] || [ "$geo_exists_geosite_zkeen" = "installed" ]) && has_updatable_geosite_bases=true

    while true; do
        install_antifilter_geosite=false
        install_v2fly_geosite=false
        install_zkeen_geosite=false
        update_antifilter_geosite=false
        update_v2fly_geosite=false
        update_zkeen_geosite=false
        choice_delete_geosite_antifilter_select=false
        choice_delete_geosite_v2fly_select=false
        choice_delete_geosite_zkeen_select=false
        invalid_choice=false

        echo 
        echo 
        echo -e "  Выберите номер или номера действий для ${yellow}GeoSite${reset}"
        echo 

        [ "$has_missing_geosite_bases" = true ] && echo "     1. Установить отсутствующие GeoSite" || echo -e "     1. ${gray}Все доступные GeoSite установлены${reset}"
        [ "$has_updatable_geosite_bases" = true ] && echo "     2. Обновить установленные GeoSite" || echo -e "     2. ${gray}Нет доступных GeoSite для обновления${reset}"

        [ "$geo_exists_geosite_antifilter" != "installed" ] && antifilter_choice="Установить" || antifilter_choice="Обновить"
        [ "$geo_exists_geosite_v2fly" != "installed" ] && v2fly_choice="Установить" || v2fly_choice="Обновить"
        [ "$geo_exists_geosite_zkeen" != "installed" ] && zkeen_choice="Установить" || zkeen_choice="Обновить"

        echo "     3. $antifilter_choice AntiFilter"
        echo "     4. $v2fly_choice v2fly"
        echo "     5. $zkeen_choice Zkeen"
        echo 
        echo "     0. Пропустить"

        [ "$has_updatable_geosite_bases" = true ] && echo && echo "     99. Удалить установленные GeoSite"

        echo
        geosite_choices=$(input_digits "Ваш выбор: " "${red}Некорректный номер действия.${reset} Пожалуйста, выберите снова")

        for choice in $geosite_choices; do
            if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
                echo -e "  ${red}Некорректный номер действия.${reset} Пожалуйста, выберите снова"
                invalid_choice=true
                sleep 1
                break
            fi
        done

        [ "$invalid_choice" = true ] && continue

        for choice in $geosite_choices; do
            case "$choice" in
                1)
                    if [ "$has_missing_geosite_bases" = false ]; then
                        echo -e "  Все GeoSite ${green}уже установлены${reset}"
                        if input_concordance_list "Вы хотите обновить их?"; then
                            update_antifilter_geosite=true
                            update_v2fly_geosite=true
                            update_zkeen_geosite=true
                        else
                            invalid_choice=true
                        fi
                    else
                        [ "$geo_exists_geosite_antifilter" != "installed" ] && install_antifilter_geosite=true
                        [ "$geo_exists_geosite_v2fly" != "installed" ] && install_v2fly_geosite=true
                        [ "$geo_exists_geosite_zkeen" != "installed" ] && install_zkeen_geosite=true
                    fi
                    ;;
                2)
                    if [ "$has_updatable_geosite_bases" = false ]; then
                        echo -e "  ${red}Нет установленных GeoSite${reset} для обновления"
                        if input_concordance_list "Вы хотите установить их?"; then
                            install_antifilter_geosite=true
                            install_v2fly_geosite=true
                            install_zkeen_geosite=true
                        else
                            invalid_choice=true
                        fi
                    else
                        [ "$geo_exists_geosite_antifilter" = "installed" ] && update_antifilter_geosite=true
                        [ "$geo_exists_geosite_v2fly" = "installed" ] && update_v2fly_geosite=true
                        [ "$geo_exists_geosite_zkeen" = "installed" ] && update_zkeen_geosite=true
                    fi
                    ;;
                3)
                    [ "$geo_exists_geosite_antifilter" != "installed" ] && install_antifilter_geosite=true || update_antifilter_geosite=true
                    ;;
                4)
                    [ "$geo_exists_geosite_v2fly" != "installed" ] && install_v2fly_geosite=true || update_v2fly_geosite=true
                    ;;
                5)
                    [ "$geo_exists_geosite_zkeen" != "installed" ] && install_zkeen_geosite=true || update_zkeen_geosite=true
                    ;;
                0)
                    echo "  Выполнен пропуск установки / обновления GeoSite"
                    return
                    ;;
                99)
                    if [ "$has_updatable_geosite_bases" = false ]; then
                        echo -e "  ${red}Нет установленных GeoSite для удаления${reset}. Выберите другой пункт"
                        invalid_choice=true
                    else
                        choice_delete_geosite_antifilter_select=true
                        choice_delete_geosite_v2fly_select=true
                        choice_delete_geosite_zkeen_select=true
                    fi
                    ;;
                *)
                    echo -e "  ${red}Некорректный номер действия: $choice${reset}. Пожалуйста, выберите снова"
                    invalid_choice=true
                    ;;
            esac
        done

        [ "$invalid_choice" = true ] && continue

        install_list=""
        update_list=""
        delete_list=""

        [ "$install_antifilter_geosite" = true ] && install_list="$install_list ${yellow}AntiFilter${reset},"
        [ "$install_v2fly_geosite" = true ] && install_list="$install_list ${yellow}v2fly${reset},"
        [ "$install_zkeen_geosite" = true ] && install_list="$install_list ${yellow}Zkeen${reset},"
        [ "$update_antifilter_geosite" = true ] && update_list="$update_list ${yellow}AntiFilter${reset},"
        [ "$update_v2fly_geosite" = true ] && update_list="$update_list ${yellow}v2fly${reset},"
        [ "$update_zkeen_geosite" = true ] && update_list="$update_list ${yellow}Zkeen${reset},"
        [ "$choice_delete_geosite_antifilter_select" = true ] && delete_list="$delete_list ${yellow}AntiFilter${reset},"
        [ "$choice_delete_geosite_v2fly_select" = true ] && delete_list="$delete_list ${yellow}v2fly${reset},"
        [ "$choice_delete_geosite_zkeen_select" = true ] && delete_list="$delete_list ${yellow}Zkeen${reset},"

        if [ -n "$install_list" ]; then
            echo -e "  Устанавливаются следующие GeoSite: ${install_list%,}"
        fi

        if [ -n "$update_list" ]; then
            echo -e "  Обновляются следующие GeoSite: ${update_list%,}"
        fi

        if [ -n "$delete_list" ]; then
            echo -e "  Удаляются следующие GeoSite: ${delete_list%,}"
        fi

        break
    done
}