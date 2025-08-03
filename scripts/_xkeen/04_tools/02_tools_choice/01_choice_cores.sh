# Запрос на добавление ядер проксирования
choice_add_proxy_cores() {
    while true; do
        echo
        echo -e "  Выберите ${yellow}ядро проксирования${reset} для загрузки и установки:"
        echo
        echo "     1. Xray"
        echo "     2. Mihomo"
        echo "     3. Xray + Mihomo"
        echo
        echo "     0. Пропустить загрузку ядра проксирования, если оно уже установлено"
        echo

        valid_input=true
        add_xray=false
        add_mihomo=false

        while true; do
            read -r -p "  Ваш выбор: " proxy_choice
            proxy_choice=$(echo "$proxy_choice" | sed 's/,/, /g')

            if echo "$proxy_choice" | grep -qE '^[0-3]$'; then
                break
            else
                echo -e "  ${red}Некорректный ввод.${reset} Выберите один из предложенных вариантов"
            fi
        done

        case "$proxy_choice" in
            1)
                add_xray=true
                ;;
            2)
                add_mihomo=true
                ;;
            3)
                add_xray=true
                add_mihomo=true
                ;;
            0)
                add_xray=false
                add_mihomo=false
                ;;
            *)
                echo -e "  ${red}Некорректный ввод${reset}"
                valid_input=false
                ;;
        esac

        [ "$valid_input" = "true" ] && break
    done
}

# Смена ядра проксирования на Xray
choice_xray_core() {  
    command -v xray >/dev/null 2>&1 || { echo -e "  ${red}Ошибка${reset}: Ядро Xray не установлено. Выполните установку командой ${yellow}xkeen -ux${reset}"; exit 1; }
    if grep -q 'name_client="xray"' $initd_dir/S24xray; then
        echo -e " Смена ядра ${red}не выполнена${reset}. Устройство уже работает на ядре ${yellow}Xray${reset}"
    elif grep -q 'name_client="mihomo"' $initd_dir/S24xray; then
        if pidof "mihomo" >/dev/null; then
            $initd_dir/S24xray stop
        fi
        sed -i 's/name_client="mihomo"/name_client="xray"/' $initd_dir/S24xray
        add_chmod_init
        echo -e "  ${green}Выполнена${reset} смена ядра на ${yellow}Xray${reset}"
        echo -e "  Настройте конфигурацию по пути '${yellow}$install_conf_dir/${reset}'"
        echo -e "  И запустите проксирование командой ${yellow}xkeen -start${reset}"
    else
        echo -e " Произошла ${red}ошибка${reset} при смене ядра проксирования"
    fi
}

# Смена ядра проксирования на Mihomo
choice_mihomo_core() {
    command -v mihomo >/dev/null 2>&1 || { echo -e "  ${red}Ошибка${reset}: Ядро Mihomo не установлено. Выполните установку командой ${yellow}xkeen -um${reset}"; exit 1; }
    command -v yq >/dev/null 2>&1 || { echo -e "  ${red}Ошибка${reset}: не установлен парсер конфигурационных файлов Mihomo - ${yellow}Yq${reset}"; exit 1; }
    if grep -q 'name_client="mihomo"' $initd_dir/S24xray; then
        echo -e " Смена ядра ${red}не выполнена${reset}. Устройство уже работает на ядре ${yellow}Mihomo${reset}"
    elif [ -f "$install_dir/mihomo" ] && [ -f "$install_dir/yq" ] && grep -q 'name_client="xray"' $initd_dir/S24xray; then
        if pidof "xray" >/dev/null; then
            $initd_dir/S24xray stop
        fi
        sed -i 's/name_client="xray"/name_client="mihomo"/' $initd_dir/S24xray
        add_chmod_init
        echo -e "  ${green}Выполнена${reset} смена ядра на ${yellow}Mihomo${reset}"
        echo -e "  Настройте конфигурацию по пути '${yellow}$mihomo_conf_dir/${reset}'"
        echo -e "  И запустите проксирование командой ${yellow}xkeen -start${reset}"
    else
        echo -e " Произошла ${red}ошибка${reset} при смене ядра проксирования"
    fi
}