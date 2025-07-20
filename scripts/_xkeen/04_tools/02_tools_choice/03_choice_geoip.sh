# Функция для выбора вариантов GeoIP
choice_geoip() {
    has_missing_geoip_bases=false
    has_updatable_geoip_bases=false

    for source in refilter v2fly zkeenip; do
        var="update_${source}_geoip"
        msg_var="update_${source}_geoip_msg"
        
        if [ "$(eval echo \$$var)" = "false" ]; then
            has_missing_geoip_bases=true
        else
            eval "$msg_var=true"
            has_updatable_geoip_bases=true
        fi
    done

    while true; do
        install_refilter_geoip=false
        install_v2fly_geoip=false
        install_zkeenip_geoip=false
        update_refilter_geoip=false
        update_v2fly_geoip=false
        update_zkeenip_geoip=false
        choice_delete_geoip_refilter_select=false
        choice_delete_geoip_v2fly_select=false
        choice_delete_geoip_zkeenip_select=false
        invalid_choice=false

        echo 
        echo -e "  Выберите номер или номера действий через пробел для ${yellow}GeoIP${reset}"
        echo 

        [ "$has_missing_geoip_bases" = true ] && echo "     1. Установить отсутствующие GeoIP" || echo -e "     1. ${gray}Все доступные GeoIP установлены${reset}"
        [ "$has_updatable_geoip_bases" = true ] && echo "     2. Обновить установленные GeoIP" || echo -e "     2. ${gray}Нет доступных GeoIP для обновления${reset}"

        [ "$update_refilter_geoip_msg" = "true" ] && refilter_choice="Обновить" || refilter_choice="Установить"
        [ "$update_v2fly_geoip_msg" = "true" ] && v2fly_choice="Обновить" || v2fly_choice="Установить"
        [ "$update_zkeenip_geoip_msg" = "true" ] && zkeenip_choice="Обновить" || zkeenip_choice="Установить"

        echo "     3. $refilter_choice Re:filter"
        echo "     4. $v2fly_choice v2fly"
        echo "     5. $zkeenip_choice ZkeenIP"
        echo 
        echo "     0. Пропустить"

        [ "$has_updatable_geoip_bases" = true ] && echo && echo "     6. Удалить установленные GeoIP"

        echo
        valid_input=true
        
        while true; do
            read -r -p "  Ваш выбор: " geoip_choices
            geoip_choices=$(echo "$geoip_choices" | sed 's/,/, /g')

            if echo "$geoip_choices" | grep -qE '^[0-6 ]+$'; then
                break
            else
                echo -e "  ${red}Некорректный ввод.${reset} Пожалуйста, выберите снова"
            fi
        done

        for choice in $geoip_choices; do
            case "$choice" in
                1)
                    if [ "$has_missing_geoip_bases" = false ]; then
                        echo -e "  Все GeoIP ${green}уже установлены${reset}"
                        if input_concordance_list "Вы хотите обновить их?"; then
                            update_refilter_geoip=true
                            update_v2fly_geoip=true
                            update_zkeenip_geoip=true
                        else
                            invalid_choice=true
                        fi
                    else
                        [ "$update_refilter_geoip_msg" != "true" ] && install_refilter_geoip=true
                        [ "$update_v2fly_geoip_msg" != "true" ] && install_v2fly_geoip=true
                        [ "$update_zkeenip_geoip_msg" != "true" ] && install_zkeenip_geoip=true
                    fi
                    ;;
                2)
                    if [ "$has_updatable_geoip_bases" = "false" ]; then
                        echo -e "  ${red}Нет установленных GeoIP${reset} для обновления"
                        if input_concordance_list "Вы хотите установить их?"; then
                            install_refilter_geoip=true
                            install_v2fly_geoip=true
                            install_zkeenip_geoip=true
                        else
                            invalid_choice=true
                        fi
                    else
                        [ "$update_refilter_geoip_msg" = "true" ] && update_refilter_geoip=true
                        [ "$update_v2fly_geoip_msg" = "true" ] && update_v2fly_geoip=true
                        [ "$update_zkeenip_geoip_msg" = "true" ] && update_zkeenip_geoip=true
                    fi
                    ;;
                3)
                    [ "$update_refilter_geoip_msg" != "true" ] && install_refilter_geoip=true || update_refilter_geoip=true
                    ;;
                4)
                    [ "$update_v2fly_geoip_msg" != "true" ] && install_v2fly_geoip=true || update_v2fly_geoip=true
                    ;;
                5)
                    [ "$update_zkeenip_geoip_msg" != "true" ] && install_zkeenip_geoip=true || update_zkeenip_geoip=true
                    ;;
                0)
                    echo "  Выполнен пропуск установки / обновления GeoIP"
                    return
                    ;;
                6)
                    if [ "$has_updatable_geoip_bases" = "false" ]; then
                        echo -e "  ${red}Нет установленных GeoIP для удаления${reset}. Выберите другой пункт"
                        invalid_choice=true
                    else
                        choice_delete_geoip_refilter_select=true
                        choice_delete_geoip_v2fly_select=true
                        choice_delete_geoip_zkeenip_select=true
                    fi
                    ;;
                *)
                    echo -e "  ${red}Некорректный ввод.${reset} Пожалуйста, выберите снова"
                    invalid_choice=true
                    ;;
            esac
        done

        [ "$invalid_choice" = true ] && continue

        install_list=
        update_list=
        delete_list=

        [ "$install_refilter_geoip" = true ] && install_list="$install_list ${yellow}Re:filter${reset},"
        [ "$install_v2fly_geoip" = true ] && install_list="$install_list ${yellow}v2fly${reset},"
        [ "$install_zkeenip_geoip" = true ] && install_list="$install_list ${yellow}ZkeenIP${reset},"
        [ "$update_refilter_geoip" = true ] && update_list="$update_list ${yellow}Re:filter${reset},"
        [ "$update_v2fly_geoip" = true ] && update_list="$update_list ${yellow}v2fly${reset},"
        [ "$update_zkeenip_geoip" = true ] && update_list="$update_list ${yellow}ZkeenIP${reset},"
        [ "$choice_delete_geoip_refilter_select" = true ] && delete_list="$delete_list ${yellow}Re:filter${reset},"
        [ "$choice_delete_geoip_v2fly_select" = true ] && delete_list="$delete_list ${yellow}v2fly${reset},"
        [ "$choice_delete_geoip_zkeenip_select" = true ] && delete_list="$delete_list ${yellow}ZkeenIP${reset},"

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