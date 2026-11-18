# Определение места установки Entware
location_entware_storage() {
    preinstall_warn="false"
    mount_point=$(mount | grep 'on /opt ')
    device=$(echo "$mount_point" | awk '{print $1}')

    case "$device" in
        /dev/sd*)   entware_storage="на внешний USB-накопитель" ;;
        /dev/nvme*) entware_storage="на NVMe-накопитель" ;;
        /dev/ubi*)  entware_storage="во внутреннюю память роутера"; preinstall_warn="true" ;;
        *)          entware_storage="на неидентифицированный носитель информации" ;;
    esac
}

# Информационный варнинг при установке во внутреннюю память
preinstall_warn() {
    if [ "$preinstall_warn" = "true" ]; then
        echo
        echo -e "  ${red}Внимание${reset}: Инициирована установка XKeen $entware_storage"
        echo "  Убедитесь, что на ней достаточно свободного места. Сбой при такой"
        echo "  установке не является проблемой XKeen и багрепорт не будет рассмотрен"
        echo -e "  XKeen ${green}рекомендуется${reset} устанавливать на внешний ${green}USB-накопитель${reset}"
        echo

        if [ "$autoinstall_mode" = "true" ]; then
            echo "  Установка $entware_storage продолжается"
            return 0
        fi

        echo "  1. Продолжить установку $entware_storage"
        echo "  0. Выйти из установщика"
        echo

        while true; do
            read -r -p "  Выберите действие: " choice || exit 1

            case $choice in
                1)
                    [ -t 1 ] && clear
                    break
                    ;;
                0)
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

    local df_output free_space space_unknown
    space_unknown=false
    if ! command -v df >/dev/null 2>&1; then
        space_unknown=true
    elif df_output=$(df -m "$target_dir" 2>/dev/null); then
        free_space=$(printf '%s\n' "$df_output" | awk 'NR==2 {print $4}')
        case "$free_space" in
            ''|*[!0-9]*) space_unknown=true ;;
        esac
    else
        space_unknown=true
    fi

    if [ "$space_unknown" = "true" ]; then
        echo
        echo -e "  ${red}Внимание: не удалось определить свободное место для установки $client_name${reset}"
        echo "  Проверьте работоспособность утилиты df и состояние накопителя."
        echo
    elif [ "$free_space" -lt "$required_space" ]; then
        smart_clear
        echo
        echo -e "  ${red}Внимание: Недостаточно свободного места для установки $client_name${reset}"
        echo -e "  Требуется: ${light_blue}${required_space} MB${reset}, доступно: ${light_blue}${free_space} MB${reset}"
        echo
    else
        return 0
    fi

    if [ "$autoinstall_mode" = "true" ]; then
        if [ "$space_unknown" = "true" ]; then
            echo -e "  Установка ${yellow}$client_name${reset} отменена: объём свободного места неизвестен"
        else
            echo -e "  Установка ${yellow}$client_name${reset} отменена: недостаточно места"
        fi
        return 1
    fi

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
}
