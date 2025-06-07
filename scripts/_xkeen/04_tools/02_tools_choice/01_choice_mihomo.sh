# Запрос на добавление ядра Mihomo
choice_add_mihomo() {
    while true; do
        echo
        echo
        echo -e "  ${green}Добавить${reset} ядро ${yellow}Mihomo${reset}?"
        echo
        echo "     1. Да"
        echo "     0. Нет"
        echo

        update_choices=$(input_digits "Ваш выбор: " "${red}Некорректный номер действия. ${reset}Пожалуйста, выберите снова")

        valid_input=true
        add_mihomo=true

        for choice in $update_choices; do
            if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
                echo -e "  ${red}Некорректный номер действия.${reset}"
                valid_input=false
                break
            fi
        done

        if ! $valid_input; then
            continue
        fi

        for choice in $update_choices; do
            case "$choice" in
                0)
                    add_mihomo=false
                    ;;
                1)
                    sleep 1
                    ;;
                *)
                    echo -e "  ${red}Некорректный номер действия.${reset}"
                    valid_input=false
                    break
                    ;;
            esac
        done

        if $valid_input; then
            break
        fi
    done
}