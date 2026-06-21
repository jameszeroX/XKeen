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
    ip -6 addr show 2>/dev/null | grep -q "inet6 fe80::" && ip6_supported="true" || ip6_supported="false"

    if [ "$1" = "on" ]; then
        if [ "$ip6_supported" = "true" ]; then
            echo -e "\n  Поддержка IPv6 в KeeneticOS ${green}уже включена${reset}"
            return 0
        fi
        desired_state="on"
    elif [ "$1" = "off" ]; then
        if [ "$ip6_supported" = "false" ]; then
            echo -e "\n  Поддержка IPv6 в KeeneticOS ${green}уже отключена${reset}"
            return 0
        fi
        desired_state="off"
    else
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
                        echo
                        if [ "$ip6_supported" = "true" ]; then
                            echo -e "  Поддержка IPv6 в KeeneticOS ${green}оставлена включённой${reset}"
                        else
                            echo -e "  Поддержка IPv6 в KeeneticOS ${green}оставлена отключённой${reset}"
                        fi
                        return 0 
                        ;;
                    1) break ;;
                esac
            else
                echo -e "  ${red}Некорректный ввод${reset}"
            fi
        done
    fi

    if [ -f "$initd_file" ]; then
        sed -i "s/ipv6_support=\"[a-z]*\"/ipv6_support=\"$desired_state\"/" "$initd_file"

        if [ "$desired_state" = "off" ]; then
            sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
            for dir in /proc/sys/net/ipv6/conf/*; do
                [ -d "$dir" ] || continue
                iface="${dir##*/}"
                case "$iface" in
                    all|ezcfg0|t2s*) continue ;;
                    *) [ -f "$dir/disable_ipv6" ] && echo "1" > "$dir/disable_ipv6" 2>/dev/null ;;
                esac
            done
        else
            sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>&1
            sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>&1
        fi

        # Перезапуск прокси-клиента, если запущен
        if pidof xray >/dev/null || pidof mihomo >/dev/null; then
            echo && echo -e "  ${yellow}Выполняется${reset}. Пожалуйста, подождите..."
            "$initd_file" restart on >/dev/null 2>&1
        fi

        # Проверка и вывод результата
        if [ "$desired_state" = "off" ]; then
            echo
            if ! ip -6 addr show 2>/dev/null | grep -q "inet6 fe80::"; then
                echo -e "  Поддержка IPv6 в KeeneticOS ${green}отключена${reset}"
                echo -e "  ${red}Дополнительно убедитесь, что IPv6 отключен в веб-интерфейсе роутера${reset}"
            else
                echo -e "  ${red}Ошибка${reset} при выключении IPv6"
            fi
        else
            echo
            if [ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)" -eq 0 ]; then
                echo -e "  Поддержка IPv6 в KeeneticOS ${green}включена${reset}"
            else
                echo -e "  ${red}Ошибка${reset} при включении IPv6"
            fi
        fi
    else
        echo -e "  ${red}Ошибка${reset}: Не найден файл автозапуска ${yellow}S05xkeen${reset}"
        return 1
    fi
}

choice_backup_xkeen() {
    [ -f "$initd_file" ] || return 1
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

check_file_descriptors() {
    pid=""
    if pid=$(pidof xray | awk '{print $1}') && [ -n "$pid" ]; then
        name_client="xray"
    elif pid=$(pidof mihomo | awk '{print $1}') && [ -n "$pid" ]; then
        name_client="mihomo"
    else
        echo -e "\n  Команда работает только при работающем ${yellow}XKeen${reset}"
        return 1
    fi

    fd_count=$(ls /proc/"$pid"/fd | wc -l)

    maxfd=$(grep 'Max open files' "/proc/$pid/limits" | awk '{print $4}')

    echo -e "\n  Прокси-клиент ${light_blue}$name_client${reset} открыл файловых дескрипторов - ${green}$fd_count${reset}"
    echo -e "  Лимит файловых дескрипторов для вашего роутера  - ${green}$maxfd${reset}"
    echo -e "\n  При высоких значениях открытых файловых дескрипторов,"
    echo -e "  можете включить их контроль командой ${yellow}xkeen -fd${reset}"
}

warn_proxy_dns() {
    echo
    echo -e "  ${red}Внимание!${reset} Значение данного параметра без соответствующих настроек прокси-клиента ${green}игнорируется${reset}"
}

change_proxy_dns() {
    toggle_param "proxy_dns" "перехвата DNS" "restart" "$1"
}

change_autostart_xkeen() {
    toggle_param "start_auto" "автозапуска XKeen" "none" "$1"
}

change_file_descriptors() {
    toggle_param "check_fd" "контроля файловых дескрипторов" "restart" "$1"
}

change_proxy_router() {
    toggle_param "proxy_router" "проксирования трафика Entware" "restart" "$1"
}

change_pbr_strict() {
    toggle_param "pbr_strict" "strict PBR-проверки для исходящих подключений Xray/Mihomo" "restart" "$1"
}

_pbr_hex_to_decimal() {
    mark="$1"
    mark="${mark#0x}"
    mark="${mark#0X}"

    case "$mark" in
        ''|*[!0-9a-fA-F]*) return 1 ;;
    esac

    printf '%s\n' "$mark" | awk '
        BEGIN { digits = "0123456789abcdef" }
        {
            value = 0
            mark = tolower($0)
            for (i = 1; i <= length(mark); i++) {
                digit = substr(mark, i, 1)
                pos = index(digits, digit)
                if (pos == 0) {
                    exit 1
                }
                value = value * 16 + pos - 1
            }
            printf "%.0f\n", value
        }
    '
}

show_pbr_policy_codes() {
    policy_api_url="localhost:79/rci/show/ip/policy"
    main_policy_name="xkeen"

    echo
    api_policy_json=$(curl_api "$policy_api_url" 2>/dev/null)
    if [ -z "$api_policy_json" ]; then
        echo -e "  ${red}Ошибка${reset}: Не удалось получить список политик из веб-интерфейса Keenetic"
        return 1
    fi

    main_policy_mark=$(printf '%s' "$api_policy_json" | jq -r --arg pname "$main_policy_name" '
        .[] | select((.description // "" | ascii_downcase) == ($pname | ascii_downcase)) | .mark // empty
    ' 2>/dev/null | head -n 1)

    user_policy_marks=""
    if [ -f "$xkeen_config" ]; then
        user_policy_marks=$(printf '%s' "$api_policy_json" | jq -r --argjson user_cfg "$(cat "$xkeen_config")" '
            ($user_cfg.xkeen.policy // []) as $up |
            .[] as $api |
            $up[] |
            select((.name // "" | ascii_downcase) == ($api.description // "" | ascii_downcase)) |
            "\(.name)|\($api.mark // "")"
        ' 2>/dev/null)
    fi

    echo -e "  Коды политик Keenetic для ${yellow}mark${reset} / ${yellow}routing-mark${reset}:"
    echo

    if [ -n "$main_policy_mark" ]; then
        main_policy_dec=$(_pbr_hex_to_decimal "$main_policy_mark" 2>/dev/null)
        echo "xkeen=$main_policy_dec"
    else
        echo "xkeen="
    fi

    if [ -n "$user_policy_marks" ]; then
        printf '%s\n' "$user_policy_marks" | while IFS='|' read -r policy_name policy_mark; do
            [ -n "$policy_name" ] || continue
            [ -n "$policy_mark" ] || continue
            policy_dec=$(_pbr_hex_to_decimal "$policy_mark" 2>/dev/null) || continue
            echo "${policy_name}=${policy_dec}"
        done
    fi

    echo
    echo "  Для mark / routing-mark используйте только число справа от '='"
}

show_pbr_strict_status() {
    echo
    if [ ! -f "$initd_file" ]; then
        echo -e "  ${red}Ошибка${reset}: Не найден файл ${yellow}S05xkeen${reset}"
        return 1
    fi

    current_state=$(grep -m 1 -E '^[[:space:]]*pbr_strict=' "$initd_file" | cut -d'=' -f2 | tr -d '"[:space:]')
    [ -z "$current_state" ] && current_state="off"

    if [ "$current_state" = "on" ]; then
        echo -e "  Strict PBR-проверка ${green}включена${reset}"
        echo -e "  XKeen проверяет, что исходящие подключения ${yellow}Xray/Mihomo${reset} используют корректный mark/routing-mark политики Keenetic"
    else
        echo -e "  Strict PBR-проверка ${red}выключена${reset}"
        echo -e "  XKeen не проверяет mark/routing-mark перед запуском"
        echo -e "  Если mark/routing-mark уже указан в конфиге ${yellow}Xray/Mihomo${reset}, он продолжит применяться самим ядром/системой"
    fi
    echo -e "  Управление: ${yellow}xkeen -pbr on${reset} | ${yellow}xkeen -pbr off${reset} | ${yellow}xkeen -pbr status${reset} | ${yellow}xkeen -pbr codes${reset}"
}

change_extended_msg() {
    toggle_param "extended_msg" "расширенных сообщений при запуcке XKeen" "none" "$1"
}

change_backup_xkeen() {
    toggle_param "backup" "резервного копирования XKeen при обновлении" "none" "$1"
}

change_aghfix_xkeen() {
    toggle_param "aghfix" "отображения клиентов XKeen под своими IP в журнале AaGuard Home" "restart" "$1"
}
