# Определение места установки Entware
tests_entware_storage() {
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