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