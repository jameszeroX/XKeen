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

# Функция для ввода только цифровых символов
input_digits() {
    prompt_message="${1:-Введите числа: }"
    error_message="${2:-${red}Некорректный ввод.${reset} Буквенные выражения не принимаются, ${yellow}используйте цифры${reset}.}"

    while true; do
        read -r -p "  $prompt_message" input
        input=$(echo "$input" | sed 's/,/, /g')
        if echo "$input" | grep -qE '^[0-9 ]+$'; then
            echo "$input"
            return 0
        else
            echo -e "  $error_message"
        fi
    done
}
