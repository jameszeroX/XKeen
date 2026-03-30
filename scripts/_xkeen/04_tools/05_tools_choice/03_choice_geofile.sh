choice_geodata() {
    type="$1"
    type_name="$2"
    src3="$3"
    src3_name="$4"
    var_bypass="$5"

    has_missing_bases=false
    has_updatable_bases=false

    for source in refilter v2fly "$src3"; do
        var="update_${source}_${type}"
        msg_var="update_${source}_${type}_msg"

        if [ "$(eval echo \$$var)" = "false" ]; then
            has_missing_bases=true
        else
            eval "$msg_var=true"
            has_updatable_bases=true
        fi
    done

    while true; do
        eval "install_refilter_${type}=false"
        eval "install_v2fly_${type}=false"
        eval "install_${src3}_${type}=false"
        eval "update_refilter_${type}=false"
        eval "update_v2fly_${type}=false"
        eval "update_${src3}_${type}=false"
        eval "choice_delete_${type}_refilter_select=false"
        eval "choice_delete_${type}_v2fly_select=false"
        eval "choice_delete_${type}_${src3}_select=false"
        invalid_choice=false

        echo 
        echo -e "  Выберите номер или номера действий через пробел для ${yellow}${type_name}${reset}"
        echo 

        [ "$has_missing_bases" = true ] && echo "     1. Установить отсутствующие и обновить установленные ${type_name}" || echo -e "     1. ${italic}Все доступные ${type_name} установлены${reset}"
        [ "$has_updatable_bases" = true ] && echo "     2. Обновить установленные ${type_name}" || echo -e "     2. ${italic}Нет доступных ${type_name} для обновления${reset}"

        [ "$(eval echo \$update_refilter_${type}_msg)" = "true" ] && refilter_choice="Обновить" || refilter_choice="Установить"
        [ "$(eval echo \$update_v2fly_${type}_msg)" = "true" ] && v2fly_choice="Обновить" || v2fly_choice="Установить"
        [ "$(eval echo \$update_${src3}_${type}_msg)" = "true" ] && src3_choice="Обновить" || src3_choice="Установить"

        echo "     3. $refilter_choice Re:filter"
        echo "     4. $v2fly_choice v2fly"
        echo "     5. $src3_choice ${src3_name}"
        echo 
        echo "     0. Пропустить"

        [ "$has_updatable_bases" = true ] && echo && echo "     6. Удалить установленные ${type_name}"

        echo
        valid_input=true

        while true; do
            read -r -p "  Ваш выбор: " data_choices
            data_choices=$(echo "$data_choices" | sed 's/,/, /g')

            if echo "$data_choices" | grep -qE '^[0-6 ]+$'; then
                break
            else
                echo -e "  ${red}Некорректный ввод.${reset} Пожалуйста, выберите снова"
            fi
        done

        for choice in $data_choices; do
            case "$choice" in
                1)
                    if [ "$has_missing_bases" = "false" ]; then
                        echo -e "  Все ${type_name} ${green}уже установлены${reset}"
                        if input_concordance_list "Вы хотите обновить их?"; then
                            eval "update_refilter_${type}=true"
                            eval "update_v2fly_${type}=true"
                            eval "update_${src3}_${type}=true"
                        else
                            invalid_choice=true
                        fi
                    else
                        [ "$(eval echo \$update_refilter_${type}_msg)" != "true" ] && eval "install_refilter_${type}=true"
                        [ "$(eval echo \$update_v2fly_${type}_msg)" != "true" ] && eval "install_v2fly_${type}=true"
                        [ "$(eval echo \$update_${src3}_${type}_msg)" != "true" ] && eval "install_${src3}_${type}=true"

                        [ "$(eval echo \$update_refilter_${type}_msg)" = "true" ] && eval "update_refilter_${type}=true"
                        [ "$(eval echo \$update_v2fly_${type}_msg)" = "true" ] && eval "update_v2fly_${type}=true"
                        [ "$(eval echo \$update_${src3}_${type}_msg)" = "true" ] && eval "update_${src3}_${type}=true"
                    fi
                    ;;
                2)
                    if [ "$has_updatable_bases" = "false" ]; then
                        echo -e "  ${red}Нет установленных ${type_name}${reset} для обновления"
                        if input_concordance_list "Вы хотите установить их?"; then
                            eval "install_refilter_${type}=true"
                            eval "install_v2fly_${type}=true"
                            eval "install_${src3}_${type}=true"
                        else
                            invalid_choice=true
                        fi
                    else
                        [ "$(eval echo \$update_refilter_${type}_msg)" = "true" ] && eval "update_refilter_${type}=true"
                        [ "$(eval echo \$update_v2fly_${type}_msg)" = "true" ] && eval "update_v2fly_${type}=true"
                        [ "$(eval echo \$update_${src3}_${type}_msg)" = "true" ] && eval "update_${src3}_${type}=true"
                    fi
                    ;;
                3)
                    [ "$(eval echo \$update_refilter_${type}_msg)" != "true" ] && eval "install_refilter_${type}=true" || eval "update_refilter_${type}=true"
                    ;;
                4)
                    [ "$(eval echo \$update_v2fly_${type}_msg)" != "true" ] && eval "install_v2fly_${type}=true" || eval "update_v2fly_${type}=true"
                    ;;
                5)
                    [ "$(eval echo \$update_${src3}_${type}_msg)" != "true" ] && eval "install_${src3}_${type}=true" || eval "update_${src3}_${type}=true"
                    ;;
                6)
                    if [ "$has_updatable_bases" = "false" ]; then
                        echo -e "  ${red}Нет установленных ${type_name} для удаления${reset}. Выберите другой пункт"
                        invalid_choice=true
                    else
                        eval "choice_delete_${type}_refilter_select=true"
                        eval "choice_delete_${type}_v2fly_select=true"
                        eval "choice_delete_${type}_${src3}_select=true"
                    fi
                    ;;
                0)
                    echo "  Выполнен пропуск установки / обновления ${type_name}"
                    if [ "$has_updatable_bases" = "true" ]; then
                        eval "$var_bypass=false"
                    else
                        eval "$var_bypass=true"
                    fi
                    return
                    ;;

                *)
                    echo -e "  ${red}Некорректный ввод.${reset} Пожалуйста, выберите снова"
                    invalid_choice=true
                    ;;
            esac
        done

        [ "$invalid_choice" = true ] && continue

        install_list=""
        update_list=""
        delete_list=""

        [ "$(eval echo \$install_refilter_${type})" = "true" ] && install_list="$install_list ${yellow}Re:filter${reset},"
        [ "$(eval echo \$install_v2fly_${type})" = "true" ] && install_list="$install_list ${yellow}v2fly${reset},"
        [ "$(eval echo \$install_${src3}_${type})" = "true" ] && install_list="$install_list ${yellow}${src3_name}${reset},"

        [ "$(eval echo \$update_refilter_${type})" = "true" ] && update_list="$update_list ${yellow}Re:filter${reset},"
        [ "$(eval echo \$update_v2fly_${type})" = "true" ] && update_list="$update_list ${yellow}v2fly${reset},"
        [ "$(eval echo \$update_${src3}_${type})" = "true" ] && update_list="$update_list ${yellow}${src3_name}${reset},"

        [ "$(eval echo \$choice_delete_${type}_refilter_select)" = "true" ] && delete_list="$delete_list ${yellow}Re:filter${reset},"
        [ "$(eval echo \$choice_delete_${type}_v2fly_select)" = "true" ] && delete_list="$delete_list ${yellow}v2fly${reset},"
        [ "$(eval echo \$choice_delete_${type}_${src3}_select)" = "true" ] && delete_list="$delete_list ${yellow}${src3_name}${reset},"

        if [ -n "$install_list" ]; then
            echo -e "  Устанавливаются следующие ${type_name}: ${install_list%,}"
        fi

        if [ -n "$update_list" ]; then
            echo -e "  Обновляются следующие ${type_name}: ${update_list%,}"
        fi

        if [ -n "$delete_list" ]; then
            echo -e "  Удаляются следующие ${type_name}: ${delete_list%,}"
        fi

        break
    done

    if [ -z "$install_list" ] && [ -z "$update_list" ] && [ -z "$delete_list" ]; then
        eval "$var_bypass=true"
    else
        eval "$var_bypass=false"
    fi
}

choice_geosite() {
    choice_geodata "geosite" "GeoSite" "zkeen" "ZKeen" "bypass_cron_geosite"
}

choice_geoip() {
    choice_geodata "geoip" "GeoIP" "zkeenip" "ZKeenIP" "bypass_cron_geoip"
}