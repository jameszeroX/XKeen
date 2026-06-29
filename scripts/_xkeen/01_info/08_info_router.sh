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
    version="$(curl_api "localhost:79/rci/show/version" 2>/dev/null)"

    case "$version" in
        *KN-1212*|*KN-2310*|*KN-2311*|*KN-2910*) softfloat="true" ;;
        *) echo; return ;;
    esac
}

# Функция для получения информации о версии Keenetic OS
info_firmware() {
    json_data=""
    json_data="$(curl_api "localhost:79/rci/show/version" 2>/dev/null)"

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

# Функция проверки бинарников
check_binary_health() {
    local program="$1"
    shift

    local err
    err=$("$program" "$@" >/dev/null 2>&1)
    local rc=$?

    local error_message=""

    case "$rc" in
        126) error_message="${program} не исполняемый файл" ;;
        127) error_message="${program} или системная библиотека не найдены" ;;
        132) error_message="${program} завершился с Illegal instruction" ;;
        139) error_message="${program} завершился с Segmentation fault" ;;
        134|135) error_message="${program} аварийно завершился" ;;
        *) return 0 ;;
    esac

    echo -e "  ${red}Критическая ошибка${reset}: $error_message"
    echo -e "  Исправьте ошибку локально или ${green}переустановите Entware${reset}"
    exit 1
}

# Функция предварительной проверки исправности системы
check_health_pre() {
    local curl_err
    local exit_code

    check_binary_health busybox --help
    for prog in curl opkg grep iptables; do
        check_binary_health "$prog" --version
    done

    # Делаем быстрый HTTPS запрос
    curl_err=$(curl --connect-timeout 3 -IsS "https://$conn_URL" 2>&1 >/dev/null)
    exit_code=$?

    # Если успешно, сразу выходим из функции
    [ "$exit_code" -eq 0 ] && return 0

    # Проверка на сломанные SSL-сертификаты
    if [ "$exit_code" -eq 60 ] || [ "$exit_code" -eq 77 ] || echo "$curl_err" | grep -iqE '(certificate|ssl|ca-bundle)'; then
        printf "  ${red}Критическая ошибка${reset}: Нарушена целостность SSL-сертификатов в Entware!\n"
        printf "  Интернет доступен, но curl не может проверить безопасность HTTPS-соединения\n"
        [ -n "$curl_err" ] && printf "  ${yellow}%s${reset}\n" "$curl_err"
        printf "  Исправьте ошибку локально или ${green}переустановите Entware${reset}\n\n"
        exit 1
    fi

    return 0
}