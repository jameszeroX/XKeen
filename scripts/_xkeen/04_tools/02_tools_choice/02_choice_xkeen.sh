# Запрос на смену канала обновлений XKeen (Stable/Dev)
choice_channel_xkeen() {
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
            case "$choice" in
                1)
                    if [ "$xkeen_build" = "Stable" ]; then
                        choice_build="Dev"
                    else
                        choice_build="Stable"
                    fi
                    return 0
                    ;;
                0)
                    echo "  Остаёмся на текущей ветке XKeen"
                    return 0
                    ;;
            esac
        else
            echo -e "  ${red}Некорректный ввод${reset}"
        fi
    done
}

change_channel_xkeen() {
    echo
    if [ "$choice_build" = "Stable" ]; then
        sed -i 's/^xkeen_build="[^"]*"/xkeen_build="Stable"/' "$xkeen_var_file"
        if grep -q '^xkeen_build="Stable"$' "$xkeen_var_file"; then
            echo -e "  Канал получения обновлений ${yellow}XKeen${reset} переключен на ${green}стабильную ветку${reset}"
        else
            echo -e "  ${red}Возникла ошибка${reset} при переключении канала обновлений"
            unset choice_build
        fi
    elif [ "$choice_build" = "Dev" ]; then
        sed -i 's/xkeen_build="Stable"/xkeen_build="Dev"/' $xkeen_var_file
        if grep -q '^xkeen_build="Dev"$' "$xkeen_var_file"; then
            echo -e "  Канал получения обновлений ${yellow}XKeen${reset} переключен на ${green}ветку разработки${reset}"
        else
            echo -e "  ${red}Возникла ошибка${reset} при переключении канала обновлений"
            unset choice_build
        fi
    fi
    if [ -n "$choice_build" ]; then
        echo
        echo -e "  Командой ${green}xkeen -uk${reset} вы можете обновить ${yellow}XKeen${reset} до последней версии в выбраной ветке"
    fi
}

change_autostart_xkeen() {
    if grep -q 'start_auto="on"' $initd_dir/S99xkeen; then
        sed -i 's/start_auto="on"/start_auto="off"/' $initd_dir/S99xkeen
        [ -z "$bypass_autostart_msg" ] && echo -e "  Автозапуск XKeen ${red}отключен${reset}"
    elif grep -q 'start_auto="off"' $initd_dir/S99xkeen; then
        sed -i 's/start_auto="off"/start_auto="on"/' $initd_dir/S99xkeen
        echo -e "  Автозапуск XKeen ${green}включен${reset}"
    fi
}

choice_autostart_xkeen() {
    if grep -q 'start_auto="off"' $initd_dir/S99xkeen; then
        return 1
    fi

    echo
    echo -e "  Добавить ${yellow}XKeen${reset} в автозагрузку при включении роутера?"
    echo
    echo "     1. Да"
    echo "     0. Нет"
    echo

    while true; do
        read -r -p "  Ваш выбор: " choice
        case "$choice" in
            1)
                echo -e "  Автозагрузка XKeen ${green}включена${reset}"
                return 0
                ;;
            0)
                bypass_autostart_msg="yes"
                change_autostart_xkeen
                return 0
                ;;
            *)
                echo -e "  ${red}Некорректный ввод${reset}"
                ;;
        esac
    done
}

choice_redownload_xkeen() {
    echo
    echo -e "  Выберите вариант переустановки ${yellow}XKeen${reset}"
    echo
    echo "     1. Загрузить дистрибутив XKeen из интернета"
    echo "     0. Локальная переустановка XKeen"
    echo

    while true; do
        read -r -p "  Ваш выбор: " choice
        case "$choice" in
            1)
                redownload_xkeen="yes"
                return 0
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "  ${red}Некорректный ввод${reset}"
                ;;
        esac
    done
}