# Определение места установки Entware
location_entware_storage() {
    mount_point=$(mount | grep 'on /opt ')
    device=$(echo "$mount_point" | awk '{print $1}')

    if echo "$device" | grep -q "^/dev/sd"; then
        entware_storage="на внешний USB-накопитель"
    elif echo "$device" | grep -q "^/dev/ubi"; then
        entware_storage="во внутреннюю память роутера"
        preinstall_warn="true"
    else
        entware_storage="на неидентифицированный носитель информации"
    fi
}

# Информационный варнинг при установке во внутреннюю память
preinstall_warn() {
    if [ -n "$preinstall_warn" ]; then
        echo
        echo -e "  ${red}Внимание${reset}: Инициирована установка XKeen $entware_storage"
        echo "  Убедитесь, что на ней достаточно свободного места. Сбой при такой"
        echo "  установке не является проблемой XKeen и багрепорт не будет рассмотрен"
        echo -e "  XKeen ${green}рекомендуется${reset} устанавливать на внешний ${green}USB-накопитель${reset}"
        echo
        echo "  1. Продолжить установку $entware_storage"
        echo "  2. Выйти из установщика"
        echo

        while true; do
            read -p "  Выберите действие: " choice

            case $choice in
                1)
                    clear
                    break
                    ;;
                2)
                    echo
                    echo -e "  ${red}Установка отменена${reset}"
                    exit 0
                    ;;
                *)
                    echo -e "  ${red}Некорректный ввод.${reset} Выберите один из предложенных вариантов"
                    ;;
            esac
        done
    fi
}

# Проверка свободного места для установки ядер проксирования
check_free_space() {
    local client_name="$1"
    local required_space=0

    case "$client_name" in
        xray)   required_space=$xray_free_space ;;
        mihomo) required_space=$mihomo_free_space ;;
        *)      return 0 ;;
    esac

    local free_space
    free_space=$(df -m "$target_dir" | awk 'NR==2 {print $4}')

    [ -z "$free_space" ] && return 0

    if [ "$free_space" -lt "$required_space" ]; then
        smart_clear
        echo
        echo -e "  ${red}Внимание: Недостаточно свободного места для установки $client_name${reset}"
        echo -e "  Требуется: ${light_blue}${required_space} MB${reset}, доступно: ${light_blue}${free_space} MB${reset}"
        echo

        echo -e "  1) Продолжить установку ${yellow}$client_name${reset} ${red}на свой страх и риск${reset}"
        echo -e "  0) Отменить установку ${yellow}$client_name${reset} (${green}Рекомендуется${reset})"
        echo
        printf "  Выберите вариант: "
        read -r response

        case "$response" in
            1)
                echo "  Предупреждение проигнорировано. Продолжаем..."
                return 0
                ;;
            0|"")
                echo -e "  Установка ${yellow}$client_name${reset} отменена пользователем"
                return 1
                ;;
            *)
                echo -e "  Неверный ввод. В целях безопасности установка ${yellow}$client_name${reset} отменена"
                return 1
                ;;
        esac
    fi
    return 0
}