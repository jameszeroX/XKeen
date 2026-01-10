keenos_modules() {
    keenos=$(curl -kfsS "localhost:79/rci/show/version" 2>/dev/null | grep '"release"' | cut -d'"' -f4 | cut -d'.' -f1)
    modules="xt_TPROXY.ko xt_socket.ko xt_multiport.ko"

    [ -z "$keenos" ] || [ "$keenos" -lt 5 ] && modules="$modules xt_owner.ko"
}

migration_modules() {
    found_modules=""

    if [ ! -d "${user_modules}" ]; then
        echo -e "  Целевая директория ${yellow}не существует${reset}"
        echo "  Выполняется создание директории"
        mkdir -p "${user_modules}"
    fi

    for module in $modules; do
        if [ -f "${user_modules}/$module" ]; then
            found_modules="$found_modules $module"
        fi
    done

    if [ -n "$found_modules" ]; then
        echo "  В пользовательской директории уже найдены модули:"
        for module in $found_modules; do
            echo -e "    - ${yellow}$module${reset}"
        done

        echo
        echo "  Хотите заменить их новыми копиями? (1 - Да, 0 - Нет)"
        echo -e "  Старые версии модулей будут ${red}перезаписаны${reset}"

        read -r -p "  Ваш выбор: " choice
        case "$choice" in
            1 )
                echo
                echo "  Начинаю копирование с заменой..."
                ;;
            * )
                echo "  Копирование отменено"
                return 0
                ;;
        esac
    else
        echo "  Начинаю копирование модулей..."
    fi

    # Копируем модули
    copied_count=0
    total_count=0
    for module in $modules; do
        total_count=$((total_count + 1))
        cp "${os_modules}/$module" "${user_modules}"
        if [ $? -eq 0 ]; then
            echo -e "  Модуль ${yellow}$module${reset} скопирован"
            copied_count=$((copied_count + 1))
        else
            echo -e "  ${red}Ошибка${reset} при копировании модуля $module"
            echo -e "  Проверьте, установлен ли компонент роутера '${yellow}Модули ядра подсистемы Netfilter${reset}'"
            exit 1
        fi
        sleep 1
    done

    echo -e "  Необходимые для XKeen модули ${green}успешно${reset} скопированы"
    echo -e "  Если компонент роутера '${yellow}Модули ядра подсистемы Netfilter${reset}' не требуется, можете удалить его"
}

remove_modules() {
    found_modules=""

    for module in $modules; do
        if [ -f "${user_modules}/$module" ]; then
            found_modules="$found_modules $module"
        fi
    done

    if [ -n "$found_modules" ]; then
        echo "  В пользовательской директории найдены:"
        for module in $found_modules; do
            echo -e "    - ${yellow}$module${reset}"
        done

        echo
        echo "  Хотите удалить все найденные модули? (1 - Да, 0 - Нет)"
        echo -e "  Убедитесь, что компонент '${yellow}Модули ядра подсистемы Netfilter${reset}' установлен"

        read -r -p "  Ваш выбор: " choice
        case "$choice" in
            1 )
                echo
                echo "  Начинаю удаление..."
                ;;
            * )
                echo "  Удаление отменено"
                return 0
                ;;
        esac

    else
        echo "  Нет модулей для удаления"
        return 0
    fi

    removed_count=0
    total_count=0
    for module in $found_modules; do
        total_count=$((total_count + 1))
        rm -f "${user_modules}/$module"
        if [ $? -eq 0 ]; then
            echo -e "  Модуль ${yellow}$module${reset} удален"
            removed_count=$((removed_count + 1))
        else
            echo -e "  ${red}Ошибка${reset} при удалении модуля ${yellow}$module${reset}"
        fi
        sleep 1
    done

    echo -e "  Все модули ${green}успешно${reset} удалены"
    echo
    echo -e "  Чтобы XKeen начал использовать модули прошивки - ${green}перезагрузите роутер${reset}"
}