# Функция для выбора вариантов GeoIP
choose_geoip() {
    has_missing_geoip_bases=false
    has_updatable_geoip_bases=false

    # Проверяем наличие и обновляемость GeoIP баз
    [ "$geo_exists_geoip_antifilter" != "installed" ] && has_missing_geoip_bases=true
    [ "$geo_exists_geoip_v2fly" != "installed" ] && has_missing_geoip_bases=true
    [ "$geo_exists_geoip_zkeenip" != "installed" ] && has_missing_geoip_bases=true
    ([ "$geo_exists_geoip_antifilter" = "installed" ] || [ "$geo_exists_geoip_v2fly" = "installed" ] || [ "$geo_exists_geoip_zkeenip" = "installed" ]) && has_updatable_geoip_bases=true

    while true; do
        # Сброс флагов при каждом повторении цикла
        install_antifilter_geoip=false
        install_v2fly_geoip=false
        install_zkeenip_geoip=false
        update_antifilter_geoip=false
        update_v2fly_geoip=false
        update_zkeenip_geoip=false
        chose_delete_geoip_antifilter_select=false
        chose_delete_geoip_v2fly_select=false
        chose_delete_geoip_zkeenip_select=false
        invalid_choice=false

        echo 
        echo 
        echo -e "  Выберите номер или номера действий для ${yellow}GeoIP${reset}"
        echo 

        [ "$has_missing_geoip_bases" = true ] && echo "     1. Установить отсутствующие GeoIP" || echo -e "     1. ${gray}Все доступные GeoIP установлены${reset}"
        [ "$has_updatable_geoip_bases" = true ] && echo "     2. Обновить установленные GeoIP" || echo -e "     2. ${gray}Нет доступных GeoIP для обновления${reset}"

        [ "$geo_exists_geoip_antifilter" != "installed" ] && antifilter_choice="Установить" || antifilter_choice="Обновить"
        [ "$geo_exists_geoip_v2fly" != "installed" ] && v2fly_choice="Установить" || v2fly_choice="Обновить"
        [ "$geo_exists_geoip_zkeenip" != "installed" ] && zkeenip_choice="Установить" || zkeenip_choice="Обновить"

        echo "     3. $antifilter_choice AntiFilter"
        echo "     4. $v2fly_choice v2fly"
        echo "     5. $zkeenip_choice ZkeenIP"
        echo 
        echo "     0. Пропустить"
        echo 
        [ "$has_updatable_geoip_bases" = true ] && echo "     99. Удалить установленные GeoIP"
        echo
        
        geoip_choices=$(input_digits "Ваш выбор: " "${red}Некорректный номер действия.${reset} Пожалуйста, выберите снова")

        for choice in $geoip_choices; do
            if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
                echo -e "  ${red}Некорректный номер действия.${reset} Пожалуйста, выберите снова"
                invalid_choice=true
                sleep 1
                break
            fi
        done

        [ "$invalid_choice" = true ] && continue

        for choice in $geoip_choices; do
            case "$choice" in
                1)
                    if [ "$has_missing_geoip_bases" = false ]; then
                        echo -e "  Все GeoIP ${green}уже установлены${reset}"
                        if input_concordance_list "Вы хотите обновить их?"; then
                            update_antifilter_geoip=true
                            update_v2fly_geoip=true
                            update_zkeenip_geoip=true
                        else
                            invalid_choice=true
                        fi
                    else
                        [ "$geo_exists_geoip_antifilter" != "installed" ] && install_antifilter_geoip=true
                        [ "$geo_exists_geoip_v2fly" != "installed" ] && install_v2fly_geoip=true
                        [ "$geo_exists_geoip_zkeenip" != "installed" ] && install_zkeenip_geoip=true
                    fi
                    ;;
                2)
                    if [ "$has_updatable_geoip_bases" = false ]; then
                        echo -e "  ${red}Нет установленных GeoIP${reset} для обновления"
                        if input_concordance_list "Вы хотите установить их?"; then
                            install_antifilter_geoip=true
                            install_v2fly_geoip=true
                            install_zkeenip_geoip=true
                        else
                            invalid_choice=true
                        fi
                    else
                        [ "$geo_exists_geoip_antifilter" = "installed" ] && update_antifilter_geoip=true
                        [ "$geo_exists_geoip_v2fly" = "installed" ] && update_v2fly_geoip=true
                        [ "$geo_exists_geoip_zkeenip" = "installed" ] && update_zkeenip_geoip=true
                    fi
                    ;;
                3)
                    [ "$geo_exists_geoip_antifilter" != "installed" ] && install_antifilter_geoip=true || update_antifilter_geoip=true
                    ;;
                4)
                    [ "$geo_exists_geoip_v2fly" != "installed" ] && install_v2fly_geoip=true || update_v2fly_geoip=true
                    ;;
                5)
                    [ "$geo_exists_geoip_zkeenip" != "installed" ] && install_zkeenip_geoip=true || update_zkeenip_geoip=true
                    ;;
                0)
                    echo "  Выполнен пропуск установки / обновления GeoIP"
                    return
                    ;;
                99)
                    if [ "$has_updatable_geoip_bases" = false ]; then
                        echo -e "  ${red}Нет установленных GeoIP для удаления${reset}. Выберите другой пункт"
                        invalid_choice=true
                    else
                        chose_delete_geoip_antifilter_select=true
                        chose_delete_geoip_v2fly_select=true
                        chose_delete_geoip_zkeenip_select=true
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

        [ "$install_antifilter_geoip" = true ] && install_list="$install_list ${yellow}AntiFilter${reset},"
        [ "$install_v2fly_geoip" = true ] && install_list="$install_list ${yellow}v2fly${reset},"
        [ "$install_zkeenip_geoip" = true ] && install_list="$install_list ${yellow}ZkeenIP${reset},"
        [ "$update_antifilter_geoip" = true ] && update_list="$update_list ${yellow}AntiFilter${reset},"
        [ "$update_v2fly_geoip" = true ] && update_list="$update_list ${yellow}v2fly${reset},"
        [ "$update_zkeenip_geoip" = true ] && update_list="$update_list ${yellow}ZkeenIP${reset},"
        [ "$chose_delete_geoip_antifilter_select" = true ] && delete_list="$delete_list ${yellow}AntiFilter${reset},"
        [ "$chose_delete_geoip_v2fly_select" = true ] && delete_list="$delete_list ${yellow}v2fly${reset},"
        [ "$chose_delete_geoip_zkeenip_select" = true ] && delete_list="$delete_list ${yellow}ZkeenIP${reset},"

        if [ -n "$install_list" ]; then
            echo -e "  Устанавливаются следующие GeoIP: ${install_list%,}"
        fi

        if [ -n "$update_list" ]; then
            echo -e "  Обновляются следующие GeoIP: ${update_list%,}"
        fi

        if [ -n "$delete_list" ]; then
            echo -e "  Удаляются следующие GeoIP: ${delete_list%,}"
        fi

        break
    done
}