# Функция для подтверждения пользователя с вариантами "yes" и "no"
input_concordance() {
    prompt_message="  $1"
    error_message="  Пожалуйста, введите 'yes' или 'no'"

    while true; do
        echo 
        read -r -p "  $prompt_message" user_input

        case "$user_input" in
            [yY]|[yY][eE]|[yY][eE][sS]|[нН]|[нН][уУ]|[нН][уУ][ыЫ]) return 0 ;;
            [nN]|[nN][oO]|[тТ]|[тТ][щЩ]) return 1 ;;
            *)
                echo 
                echo "  $error_message"
                continue
                ;;
        esac
    done
}

# Функция для выбора пользователя между "yes" и "no" с номерами 0 и 1
input_concordance_list() {
    prompt_message="  $1"
    error_message="  ${yellow}Пожалуйста, выберите вариант, введя номер 0 (no) или 1 (yes).${reset}"

    echo
    echo -e "$prompt_message"
    echo "     0. No"
    echo "     1. Yes"

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

# Функция для ввода только буквенных символов
input_letters() {
    prompt_message="  ${1:-Введите буквы: }"
    error_message="  ${2:-${red}Некорректный ввод.${reset} Цифровые выражения не принимаются, ${yellow}используйте буквы${reset}.}"

    while true; do
        read -r -p "  $prompt_message" input
        if [[ "$input" =~ ^[a-zA-Z]+$ ]]; then
            echo 
            echo "  $input"
            break
        else
            echo 
            echo -e "  $error_message"
        fi
    done
}

# Функция для ввода только цифровых символов
input_digits() {
    prompt_message="${1:-Введите числа: }"
    error_message="${2:-${red}Некорректный ввод.${reset} Буквенные выражения не принимаются, ${yellow}используйте цифры${reset}.}"

    while true; do
        read -r -p "  $prompt_message" input
        input="${input//,/, }"
        if [[ "$input" =~ ^[0-9\ ,]+$ ]]; then
            echo 
            echo "$input"
            break
        else
            echo 
            echo -e "  $error_message"
        fi
    done
}
