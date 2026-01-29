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
    if [ -f "$initd_dir/S99xkeen" ]; then
        if grep -q 'start_auto="on"' $initd_dir/S99xkeen; then
            sed -i 's/start_auto="on"/start_auto="off"/' "$initd_dir/S99xkeen"
            [ -z "$bypass_autostart_msg" ] && echo -e "  Автозапуск XKeen ${red}отключен${reset}"
        elif grep -q 'start_auto="off"' $initd_dir/S99xkeen; then
            sed -i 's/start_auto="off"/start_auto="on"/' "$initd_dir/S99xkeen"
            echo -e "  Автозапуск XKeen ${green}включен${reset}"
        else
            echo -e "  Произошла ${red}ошибка${reset} при выполнении операции"
            return 1
        fi
    else
        echo -e "  ${red}Ошибка${reset}: Не найден файл автозапуска ${yellow}S99xkeen${reset}"
        return 1
    fi
}

choice_autostart_xkeen() {
    if [ -f "$initd_dir/S99xkeen" ] && grep -q 'start_auto="off"' $initd_dir/S99xkeen; then
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

choice_remove() {
    echo
    echo -e "  Вы действительно хотите ${red}удалить ${choice_for_remove}${reset}?"
    echo
    echo "     1. Да, хочу удалить"
    echo "     0. Нет, передумал(а)"
    echo

    while true; do
        read -r -p "  Ваш выбор (1 или 0): " choice
        case "$choice" in
            1)
                return 0
                ;;
            0)
                exit 0
                ;;
            *)
                echo -e "  ${red}Некорректный ввод${reset}"
                ;;
        esac
    done
}

choice_port_xkeen() {
    if [ "$add_ports" = "donor" ]; then
        echo -e "  Добавлять порты проксирования рекомендуется в файле ${yellow}/opt/etc/xkeen/port_proxying.lst${reset}"
    elif [ "$add_ports" = "exclude" ]; then
        echo -e "  Иключать порты из проксирования рекомендуется в файле ${yellow}/opt/etc/xkeen/port_exclude.lst${reset}"
    fi
    echo -e "  Продолжить ${red}не рекомендуемый${reset} способ?"
    echo
    echo "     1. Да, продолжаем"
    echo -e "     0. Отмена, воспользуюсь ${green}рекомендуемым${reset} способом"
    echo

    while true; do
        read -r -p "  Ваш выбор: " choice
        case "$choice" in
            1)
                return 0
                ;;
            0)
                exit 0
                ;;
            *)
                echo -e "  ${red}Некорректный ввод${reset}"
                ;;
        esac
    done
}

choice_backup_xkeen() {
    xkeen_conf="$initd_dir/S99xkeen"
    backup_value=$(grep -E '^[[:space:]]*backup[[:space:]]*=' "$xkeen_conf" | \
                   grep -v '^[[:space:]]*#' | \
                   tail -n 1 | \
                   cut -d'=' -f2 | \
                   tr -d '[:space:]"' | \
                   tr '[:upper:]' '[:lower:]')

    if [ "$backup_value" = "off" ]; then
        return 0
    else
        return 1
    fi
}

change_ipv6_support() {
    keenos=$(curl -kfsS "localhost:79/rci/show/version" | jq -r '.release' | cut -c1)

    if [ -z "$keenos" ] || [ "$keenos" -lt 5 ]; then
        echo
        echo -e "  Для управления ${yellow}протоколом IPv6${reset} обновите прошивку Keenetic до 5+ версии"
        return 1
    fi

    ip6_supported=$(ip -6 addr show | grep -q "inet6 " && echo true || echo false)

    echo
    echo -e "  Текущее состояние IPv6 в ${yellow}KeeneticOS${reset}:"
    if [ "$ip6_supported" = "true" ]; then
        echo -e "  IPv6 ${green}включён${reset}"
        echo
        echo "     1. Отключить IPv6"
        echo "     0. Оставить без изменений"
        desired_state="off"
    else
        echo -e "  IPv6 ${green}отключён${reset}"
        echo
        echo "     1. Включить IPv6"
        echo "     0. Оставить без изменений"
        desired_state="on"
    fi

    echo
    while true; do
        read -r -p "  Ваш выбор: " choice
        if echo "$choice" | grep -qE '^[0-1]$'; then
            case "$choice" in
                0)
                    return 0
                    ;;
                1)
                    break
                    ;;
            esac
        else
            echo -e "  ${red}Некорректный ввод${reset}"
        fi
    done

    if [ -f "$initd_dir/S99xkeen" ]; then
        sed -i "s/ipv6_support=\"[a-z]*\"/ipv6_support=\"$desired_state\"/" "$initd_dir/S99xkeen"
        if pidof xray >/dev/null || pidof mihomo >/dev/null; then
            echo -e "  ${yellow}Выполняется${reset}. Пожалуйста, подождите..."
            "$initd_dir/S99xkeen" restart on >/dev/null 2>&1
            if [ "$desired_state" = "off" ]; then
                echo -e "  Поддержка IPv6 в KeeneticOS ${green}отключена${reset}"
            else
                echo -e "  Поддержка IPv6 в KeeneticOS ${green}включена${reset}"
            fi
        else
            if [ "$desired_state" = "off" ]; then
                [ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)" != "1" ] && \
                    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
                [ "$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null)" != "1" ] && \
                    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
                echo -e "  Поддержка IPv6 в KeeneticOS ${green}отключена${reset}"
            else
                [ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)" != "0" ] && \
                    sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>&1
                [ "$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null)" != "0" ] && \
                    sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>&1
                echo -e "  Поддержка IPv6 в KeeneticOS ${green}включена${reset}"
            fi
        fi
    else
        echo -e "  ${red}Ошибка${reset}: Не найден файл автозапуска ${yellow}S99xkeen${reset}"
        return 1
    fi
}

change_proxy_dns() {
    if [ ! -f "$initd_dir/S99xkeen" ]; then
        echo -e "  ${red}Ошибка${reset}: Не найден файл автозапуска ${yellow}S99xkeen${reset}"
        return 1
    fi

    current_state=$(grep -E '^[[:space:]]*proxy_dns=' "$initd_dir/S99xkeen" | tail -n 1 | cut -d'=' -f2 | tr -d '"[:space:]')

    echo
    echo -e "  ${red}Внимание!${reset} Значение данного параметра без соответствующих настроек прокси-клиента ${green}игнорируется${reset}"
    echo
    echo -e "  Текущее состояние перехвата ${yellow}DNS${reset}:"

    if [ "$current_state" = "on" ]; then
        echo -e "  DNS-запросы ${green}перехватываются${reset} и направляются на прокси"
        echo
        echo "     1. Отключить перехват DNS и обрабатывать запросы роутером"
        echo "     0. Оставить без изменений"
        desired_state="off"
    else
        echo -e "  DNS-запросы ${green}обрабатываются роутером${reset}"
        echo
        echo "     1. Включить перехват и пересылку DNS-запросов на прокси"
        echo "     0. Оставить без изменений"
        desired_state="on"
    fi

    echo
    while true; do
        read -r -p "  Ваш выбор: " choice
        if echo "$choice" | grep -qE '^[0-1]$'; then
            case "$choice" in
                0)
                    return 0
                    ;;
                1)
                    break
                    ;;
            esac
        else
            echo -e "  ${red}Некорректный ввод${reset}"
        fi
    done

    sed -i "s/proxy_dns=\"[a-z]*\"/proxy_dns=\"$desired_state\"/" "$initd_dir/S99xkeen"

    if grep -q "proxy_dns=\"$desired_state\"" "$initd_dir/S99xkeen"; then
        if [ "$desired_state" = "on" ]; then
            echo -e "  Перехват DNS ${green}включён${reset}"
        else
            echo -e "  Перехват DNS ${red}отключён${reset}"
        fi

        echo
        echo -e "  Для применения изменений необходимо ${green}перезапустить XKeen${reset}"
    else
        echo -e "  ${red}Произошла ошибка${reset} при изменении настройки proxy_dns"
        return 1
    fi
}