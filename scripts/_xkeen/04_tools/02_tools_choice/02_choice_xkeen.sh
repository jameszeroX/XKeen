# Запрос на смену канала обновлений XKeen (Stable/Dev)
choice_channel_xkeen() {
    while true; do
        echo
        echo -e "  Текущий канал обновлений ${yellow}XKeen${reset}:"
        
        if [ "$xkeen_build" = "Stable" ]; then
            echo -e "  Стабильная версия (${green}Stable${reset})"
            echo
            echo "     1. Переключиться на канал разработки"
            echo "     0. Остаться на стабильной версии"
        else
            echo -e "  Версия в разработке (${green}$xkeen_build${reset})"
            echo
            echo "     1. Переключиться на стабильную версию"
            echo "     0. Остаться на версии разработки"
        fi

        echo
        while true; do
            read -r -p "  Ваш выбор: " choice
            if echo "$choice" | grep -qE '^[0-1]$'; then
                break
            else
                echo -e "  ${red}Некорректный ввод${reset}"
            fi
        done

        case "$choice" in
            1)
                if [ "$xkeen_build" = "Stable" ]; then
                    choice_build="Dev"
                else
                    choice_build="Stable"
                fi
                break
                ;;
            0)
                echo "  Остаёмся на текущей ветке XKeen"
                break
                ;;
        esac
    done
}

choice_autostart_xkeen() {
    if grep -q 'autostart="on"' $initd_dir/S99xkeenstart; then
        sed -i 's/autostart="on"/autostart="off"/' $initd_dir/S99xkeenstart
        if grep -q 'start_auto="on"' $initd_dir/S24xray; then
            sed -i 's/start_auto="on"/start_auto="off"/' $initd_dir/S24xray
        fi
        [ -z "$bypass_autostart_msg" ] && echo -e "  Автозапуск XKeen ${red}отключен${reset}"
    else
        sed -i 's/autostart="off"/autostart="on"/' $initd_dir/S99xkeenstart
        if grep -q 'start_auto="off"' $initd_dir/S24xray; then
            sed -i 's/start_auto="off"/start_auto="on"/' $initd_dir/S24xray
        fi
        echo -e "  Автозапуск XKeen ${green}включен${reset}"
    fi
}

change_autostart_xkeen() {
    if grep -q 'autostart="on"' "$initd_dir/S99xkeenstart"; then
        while true; do
            echo
            echo -e "  Включить автозагрузку ${yellow}XKeen${reset}?"
            echo
            echo "     1. Да"
            echo "     0. Нет"
            echo
            
            while true; do
                read -r -p "  Ваш выбор: " choice
                if echo "$choice" | grep -qE '^[0-1]$'; then
                    break
                else
                    echo -e "  ${red}Некорректный ввод${reset}"
                fi
            done

            case "$choice" in
                1)
                    echo -e "  Автозагрузка XKeen ${green}включена${reset}"
                    break
                    ;;
                0)
                    bypass_autostart_msg="yes"
                    choice_autostart_xkeen
                    break
                    ;;
            esac
        done
    fi
}