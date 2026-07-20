# Функция для получения информации о процессоре
info_cpu() {
    if command -v opkg >/dev/null 2>&1; then
        opkg_arch="$(opkg print-architecture | awk '!/all/ {print $2; exit}' | cut -d- -f1)"
        
        case "$opkg_arch" in
            *'aarch64'*) architecture='arm64-v8a' ;;
            *'mipsel'*) architecture='mips32le' ;;
            *'mips'*) architecture='mips32' ;;
            *) architecture="$opkg_arch" ;;
        esac
    fi

    # Получение информации о архитектуре из файла состояния (status_file)
    status_architecture="$(grep -m 1 '^Architecture:' "${status_file}" | awk '{print $2}')"

    # Получение информации о необходимости softfloat банарников
    [ "$architecture" != "mips32le" ] && echo && return
    version="$(curl_api "127.0.0.1:79/rci/show/version" 2>/dev/null)"

    case "$version" in
        *KN-1212*|*KN-2310*|*KN-2311*|*KN-2910*) softfloat="true" ;;
        *) echo; return ;;
    esac
}

# Функция для получения информации о версии Keenetic OS
info_firmware() {
    json_data=""
    json_data="$(curl_api "127.0.0.1:79/rci/show/version" 2>/dev/null)"

    if [ -z "$json_data" ]; then
        echo
        echo -e "  ${red}Ошибка${reset}: Не удалось получить данные о версии прошивки"
        exit 1
    fi

    # Получение мажорной версии Keenetic OS с помощью jq и фоллбеком на sed
    if command -v jq >/dev/null 2>&1; then
        major_version="$(echo "$json_data" | jq -r '.release // empty' | cut -d'.' -f1)"
    else
        major_version="$(echo "$json_data" | sed -n 's/.*"release"[[:space:]]*:[[:space:]]*"\([0-9][0-9]*\)\..*/\1/p')"
    fi

    if ! echo "$major_version" | grep -Eq '^[0-9]+$'; then
        clear
        echo
        echo -e "  ${yellow}Предупреждение${reset}: Не удалось определить версию KeeneticOS"
        major_version=0
    fi

    # Вывод варнинга для старых версий Keenetic OS с возможностью продолжить установку
    if [ "$major_version" -lt 4 ]; then
        [ "$major_version" = 0 ] || clear
        echo
        echo -e "  ${red}=============================================${reset}"
        echo -e "  ${red}ВНИМАНИЕ${reset}: Обнаружена KeeneticOS версии $major_version"
        echo -e "  XKeen тестируется ТОЛЬКО на ${green}KeeneticOS 4+${reset}"
        echo -e "  Работа на старых прошивках ${light_blue}НЕ гарантируется${reset}"
        echo -e "  Техподдержка разработчиком ${light_blue}НЕ предоставляетcя${reset}"
        echo -e "  ${red}=============================================${reset}"
        echo
        
        while true; do
            echo "  Выберите действие:"
            echo
            echo -e "  1) Продолжить установку ${red}на свой страх и риск${reset}"
            echo "  0) Отмена установки"
            echo
            printf "  Введите ваш выбор: "
            read -r user_input

            case "$user_input" in
                1)
                    echo "  Продолжаем установку..."
                    break
                    ;;
                0)
                    echo "  Установка отменена пользователем"
                    exit 0
                    ;;
                *)
                    echo "  Неверный ввод. Пожалуйста, введите 1 или 0."
                    echo
                    ;;
            esac
        done
    fi
}