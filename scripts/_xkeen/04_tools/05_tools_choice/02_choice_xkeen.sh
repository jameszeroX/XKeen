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

change_ipv6_support() {
    ip -6 addr show 2>/dev/null | grep -q "inet6 " && ip6_supported="true" || ip6_supported="false"

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

    if [ -f "$initd_file" ]; then
        sed -i "s/ipv6_support=\"[a-z]*\"/ipv6_support=\"$desired_state\"/" "$initd_file"
            if [ "$desired_state" = "off" ]; then
                sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
                sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
            else
                sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>&1
                sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>&1
            fi
        if pidof xray >/dev/null || pidof mihomo >/dev/null; then
            echo -e "  ${yellow}Выполняется${reset}. Пожалуйста, подождите..."
            "$initd_file" restart on >/dev/null 2>&1
        fi
        if [ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)" -eq 1 ] &&
           [ "$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null)" -eq 1 ]; then
            echo -e "  Поддержка IPv6 в KeeneticOS ${green}отключена${reset}"
            echo "  Убедитесь, что она так же отключена в веб-интерфейсе роутера"
        elif [ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)" -eq 0 ] &&
           [ "$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null)" -eq 0 ]; then
            echo -e "  Поддержка IPv6 в KeeneticOS ${green}включена${reset}"
        else
            echo -e "  ${red}Ошибка${reset} при смене статуса IPv6"
        fi
    else
        echo -e "  ${red}Ошибка${reset}: Не найден файл автозапуска ${yellow}S05xkeen${reset}"
        return 1
    fi
}

choice_backup_xkeen() {
    backup_value=$(awk -F= '/^[[:space:]]*backup[[:space:]]*=/ { gsub(/"| /,"",$2); print tolower($2); exit }' "$initd_file")
    [ "$backup_value" = "off" ]
}

choice_autostart_xkeen() {
    if [ -f "$initd_file" ] && grep -q 'start_auto="off"' "$initd_file"; then
        return 1
    fi

    if choice_menu \
        "Добавить ${yellow}XKeen${reset} в автозагрузку при включении роутера?" \
        "Да" \
        "Нет"; then
        echo -e "  Автозагрузка XKeen ${green}включена${reset}"
        return 0
    else
        bypass_autostart_msg="yes"
        change_autostart_xkeen
        unset bypass_autostart_msg
        return 0
    fi
}

choice_redownload_xkeen() {
    if choice_menu \
        "Выберите вариант переустановки ${yellow}XKeen${reset}" \
        "Загрузить дистрибутив XKeen из интернета" \
        "Локальная переустановка XKeen"; then
        redownload_xkeen="yes"
    fi
}

choice_remove() {
    if choice_menu \
        "Вы действительно хотите ${red}удалить ${choice_for_remove}${reset}?" \
        "Да, хочу удалить" \
        "Нет, передумал(а)"; then
        return 0
    else
        exit 0
    fi
}

change_autostart_xkeen() {
    toggle_param "start_auto" "автозапуска XKeen" "none"
}

change_proxy_dns() {
    toggle_param "proxy_dns" "перехвата DNS" "restart"
}

change_file_descriptors() {
    toggle_param "check_fd" "контроля файловых дескрипторов" "reboot"
}

change_proxy_router() {
    toggle_param "proxy_router" "проксирования трафика Entware" "restart"
}

change_extended_msg() {
    toggle_param "extended_msg" "расширенных сообщений при запуcке XKeen" "none"
}

change_backup_xkeen() {
    toggle_param "backup" "резервного копирования XKeen при обновлении" "none"
}