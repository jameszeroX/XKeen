# Определение времени для задач cron
# Случайное целое в диапазоне [0, $1). /dev/urandom, при его отсутствии - время и PID
_auto_rand() {
    _ar_val=$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -d ' ')
    case "$_ar_val" in
        ''|*[!0-9]*) _ar_val=$(( $(date +%s) + $$ )) ;;
    esac
    echo $(( _ar_val % $1 ))
}

choice_cron_time() {
    [ "$choice_geofile_cron_select" != true ] && return

    # Автоустановка: понедельник в случайное время с 00:00 до 05:59
    if [ "$autoinstall_mode" = "true" ]; then
        _cct_offset=$(_auto_rand 360)
        hour=$(( _cct_offset / 60 ))
        minute=$(( _cct_offset % 60 ))
        choice_geofile_cron_time="$minute $hour * * 1"
        printf "\n  Время автоматического обновления ${yellow}геофайлов${reset}: Понедельник в %02d:%02d\n\n" "$hour" "$minute"
        return 0
    fi

    echo
    echo -e "  Время автоматического обновления ${yellow}геофайлов${reset}:"
    echo
    echo "  Выберите день"
    echo "     0. Отмена"
    echo "     1. Понедельник"
    echo "     2. Вторник"
    echo "     3. Среда"
    echo "     4. Четверг"
    echo "     5. Пятница"
    echo "     6. Суббота"
    echo "     7. Воскресенье"
    echo "     8. Ежедневно"
    echo

    while :; do
        read -r -p "  Ваш выбор: " day_choice
        echo "$day_choice" | grep -qE '^[0-8]$' && break
        echo -e "  ${red}Некорректный номер действия.${reset} Пожалуйста, выберите снова"
        echo
    done

    [ "$day_choice" -eq 0 ] && {
        echo -e "  Включение автоматического обновления ${yellow}геофайлов${reset} отменено"
        echo
        return
    }

    echo

    while :; do
        read -r -p "  Выберите час (0-23): " hour
        case "$hour" in
            ''|*[!0-9]*) ;;
            *) [ "$hour" -ge 0 ] && [ "$hour" -le 23 ] && break ;;
        esac
        echo -e "  ${red}Некорректный час.${reset} Пожалуйста, попробуйте снова"
    done

    while :; do
        read -r -p "  Выберите минуту (0-59): " minute
        case "$minute" in
            ''|*[!0-9]*) ;;
            *) [ "$minute" -ge 0 ] && [ "$minute" -le 59 ] && break ;;
        esac
        echo -e "  ${red}Некорректные минуты.${reset} Пожалуйста, попробуйте снова"
    done

    if [ "$day_choice" -eq 8 ]; then
        cron_expression="$minute $hour * * *"
        day_name="Ежедневно"
    else
        case "$day_choice" in
            1) dow=1; day_name="Понедельник" ;;
            2) dow=2; day_name="Вторник" ;;
            3) dow=3; day_name="Среда" ;;
            4) dow=4; day_name="Четверг" ;;
            5) dow=5; day_name="Пятница" ;;
            6) dow=6; day_name="Суббота" ;;
            7) dow=0; day_name="Воскресенье" ;;
        esac
        cron_expression="$minute $hour * * $dow"
    fi

    case "$hour" in
        [0-9]) formatted_hour="0$hour" ;;
        *) formatted_hour="$hour" ;;
    esac
    case "$minute" in
        [0-9]) formatted_minute="0$minute" ;;
        *) formatted_minute="$minute" ;;
    esac

    echo
    echo -e "  Выбранное время обновления ${yellow}геофайлов${reset}: $day_name в $formatted_hour:$formatted_minute"
    echo

    choice_geofile_cron_time="$cron_expression"
}