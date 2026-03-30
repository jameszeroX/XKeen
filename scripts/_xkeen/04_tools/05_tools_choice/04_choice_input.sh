# Функция для выбора пользователя между "Да" и "Нет" с номерами 0 и 1
input_concordance_list() {
    prompt_message="  $1"
    error_message="  ${yellow}Пожалуйста, выберите вариант, введя номер 0 (Нет) или 1 (Да)${reset}"

    echo
    echo -e "$prompt_message"
    echo "     0. Нет"
    echo "     1. Да"

    while true; do
        echo
        read -r -p "  Введите номер: " user_input

        case "$user_input" in
            0) return 1 ;;
            1) return 0 ;;
            *)
                echo
                echo -e "  $error_message"
                continue
                ;;
        esac
    done
}

toggle_param() {
    param="$1"
    description="$2"
    restart_needed="$3"

    if [ ! -f "$initd_file" ]; then
        echo -e "  ${red}Ошибка${reset}: Не найден файл ${yellow}S05xkeen${reset}"
        return 1
    fi

    current_state=$(grep -m 1 -E "^[[:space:]]*$param=" "$initd_file" | cut -d'=' -f2 | tr -d '"[:space:]')

    if [ "$bypass_autostart_msg" = "yes" ]; then
        if [ "$current_state" = "on" ]; then
            desired_state="off"
        else
            desired_state="on"
        fi
    else
        echo
        echo -e "  Текущее состояние ${description}:"

        if [ "$current_state" = "on" ]; then
            echo -e "  ${green}Включено${reset}"
            echo
            echo "     1. Отключить"
            echo "     0. Оставить без изменений"
            desired_state="off"
        else
            echo -e "  ${red}Отключено${reset}"
            echo
            echo "     1. Включить"
            echo "     0. Оставить без изменений"
            desired_state="on"
        fi

        echo
        while true; do
            read -r -p "  Ваш выбор: " choice
            case "$choice" in
                0) return 0 ;;
                1) break ;;
                *) echo -e "  ${red}Некорректный ввод${reset}" ;;
            esac
        done
    fi

    if awk -v param="$param" -v value="$desired_state" '
        !found && $0 ~ "^[[:space:]]*" param "=" {
            sub(/"[^"]*"/, "\"" value "\"")
            found=1
        }
        {print}
    ' "$initd_file" > "$initd_file.tmp" && mv "$initd_file.tmp" "$initd_file"; then

        [ "$bypass_autostart_msg" = "yes" ] && return 0

        if [ "$desired_state" = "on" ]; then
            echo -e "  Новое состояние ${description} ${green}включено${reset}"
        else
            echo -e "  Новое состояние ${description} ${red}отключено${reset}"
        fi

        if [ "$restart_needed" = "reboot" ]; then
            echo
            echo -e "  ${yellow}Перезагрузите роутер для применения изменений${reset}"
        elif [ "$restart_needed" = "restart" ]; then
            echo
            echo -e "  ${yellow}Перезапустите XKeen для применения изменений${reset}"
        fi

        add_chmod_init
    else
        echo -e "  ${red}Ошибка${reset} при изменении параметра $param"
        return 1
    fi
}

choice_menu() {
    title="$1"
    option_yes="$2"
    option_no="$3"

    echo
    [ -n "$title" ] && echo -e "  $title"
    echo
    echo "     1. $option_yes"
    echo "     0. $option_no"
    echo

    while true; do
        read -r -p "  Ваш выбор: " choice
        case "$choice" in
            1) return 0 ;;
            0) return 1 ;;
            *) echo -e "  ${red}Некорректный ввод${reset}" ;;
        esac
    done
}