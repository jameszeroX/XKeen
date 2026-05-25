# Сформировать download_url и extension для указанной версии Xray.
# $1 = version_selected (например v25.4.30)
# Устанавливает глобальные переменные: download_url, filename, extension
# Возврат: 0 — успех, 1 — неизвестная архитектура
_xray_build_url() {
    _xbu_version="$1"
    _xbu_base="${xray_zip_url}/$_xbu_version"
    case "$architecture" in
        "arm64-v8a") download_url="$_xbu_base/Xray-linux-arm64-v8a.zip" ;;
        "mips32le")  download_url="$_xbu_base/Xray-linux-mips32le.zip" ;;
        "mips32")    download_url="$_xbu_base/Xray-linux-mips32.zip" ;;
        *)           download_url=; return 1 ;;
    esac
    filename=$(basename "$download_url")
    extension="${filename##*.}"
    return 0
}

# Загрузка Xray
download_xray() {
    USE_JSDELIVR=""
    printf "\n  ${green}Запрос информации${reset} о релизах ${yellow}Xray${reset}\n"

    # Получаем список релизов через GitHub API
    RELEASE_TAGS=$(curl_with_timeout -s "${xray_api_url}?per_page=50" 2>/dev/null | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 8)

    if [ -z "$RELEASE_TAGS" ]; then
        echo
        printf "  ${red}Нет доступа${reset} к ${yellow}GitHub API${reset}. Пробуем ${yellow}jsDelivr${reset}...\n"

        # Получаем список релизов через jsDelivr
        RELEASE_TAGS=$(curl_with_timeout -s "$xray_jsd_url" 2>/dev/null | jq -r '.versions[]' | head -n 8)

        if [ -z "$RELEASE_TAGS" ]; then
            echo
            printf "  ${red}Нет доступа${reset} к ${yellow}jsDelivr${reset}\n"
            echo
            printf "  ${red}Ошибка${reset}: Не удалось получить список релизов ни через ${yellow}GitHub API${reset}, ни через ${yellow}jsDelivr${reset}\n  Проверьте соединение с интернетом или повторите позже\n  Если ошибка сохраняется, воспользуйтесь возможностью OffLine установки:\n  https://github.com/jameszeroX/XKeen/blob/main/OffLine_install.md\n"
            echo
            exit 1
        fi
        echo
        printf "  Список релизов получен с использованием ${yellow}jsDelivr${reset}:\n"
        USE_JSDELIVR="true"
    else
        echo
        printf "  Список релизов получен с использованием ${yellow}GitHub API${reset}:\n"
    fi

    # Инициализация параметров повтора загрузки
    local max_attempts=1
    if [ -n "$retries_download" ] && [ "$retries_download" -gt 1 ] 2>/dev/null; then
        max_attempts=$retries_download
    fi
    local delay=${retry_delay_download:-2}

    if [ "$autoinstall_mode" = "true" ]; then
        version_selected=$(echo "$RELEASE_TAGS" | head -1)
        [ "$USE_JSDELIVR" = "true" ] && version_selected="v$version_selected"
        printf "  ${green}Авто-режим${reset}: выбрана последняя версия ${yellow}%s${reset}\n" "$version_selected"

        if ! _xray_build_url "$version_selected"; then
            printf "  ${red}Ошибка${reset}: Не удалось получить URL для загрузки Xray\n"
            exit 1
        fi
        mkdir -p "$xtmp_dir"

        printf "  ${yellow}Проверка${reset} доступности версии %s...\n" "$version_selected"

        probe_with_mirrors "$download_url"
        _rc=$?
        case "$_rc" in
            0)
                printf "  Файл ${green}доступен${reset}\n"
                ;;
            2)
                case "$_last_http" in
                    403) printf "  ${red}Доступ запрещен${reset} (403)\n" ;;
                    404) printf "  Файл ${red}не найден${reset} (404)\n" ;;
                    *)   printf "  ${yellow}Проблема с доступом${reset} (HTTP: %s)\n" "$_last_http" ;;
                esac
                printf "  ${red}Ошибка${reset}: Версия %s недоступна\n" "$version_selected"
                exit 1
                ;;
            *)
                if [ "$_last_curl_rc" = "28" ]; then  # curl OPERATION_TIMEDOUT
                    printf "  ${red}Таймаут${reset} при проверке\n"
                elif [ "$_last_curl_rc" != "0" ]; then
                    printf "  ${red}Ошибка curl (%s)${reset} при проверке\n" "$_last_curl_rc"
                elif [ -n "$_last_http" ] && [ "$_last_http" != "000" ]; then
                    printf "  ${yellow}Проблема с доступом${reset} (HTTP: %s)\n" "$_last_http"
                else
                    printf "  ${red}Нет соединения${reset}\n"
                fi
                printf "  ${red}Ошибка${reset}: Версия %s недоступна\n" "$version_selected"
                exit 1
                ;;
        esac

        printf "  ${yellow}Выполняется загрузка${reset} последней версии Xray\n"

        local auto_attempt=1
        local auto_success=1

        while [ "$auto_attempt" -le "$max_attempts" ]; do
            if [ "$max_attempts" -gt 1 ]; then
                printf "  Загрузка Xray (Попытка %d из %d)...\n" "$auto_attempt" "$max_attempts"
            fi

            if fetch_with_mirrors "$download_url" "$xtmp_dir/xray.$extension" 1024; then
                auto_success=0
                break
            fi

            if [ "$auto_attempt" -lt "$max_attempts" ]; then
                printf "  ${yellow}Предупреждение${reset}: Не удалось загрузить Xray. Повтор через %d сек...\n" "$delay"
                sleep "$delay"
            fi
            auto_attempt=$((auto_attempt + 1))
        done

        if [ "$auto_success" -ne 0 ]; then
            if [ "$max_attempts" -gt 1 ]; then
                printf "  ${red}Ошибка${reset}: Не удалось загрузить Xray %s после %d попыток\n" "$version_selected" "$max_attempts"
            else
                printf "  ${red}Ошибка${reset}: Не удалось загрузить Xray %s\n" "$version_selected"
            fi
            exit 1
        fi

        printf "  Xray ${green}успешно загружен${reset}\n"
        return 0
    fi

    while true; do
        echo
        echo "$RELEASE_TAGS" | awk '{printf "    %2d. %s\n", NR, $0}'
        echo
        echo "     9. Ручной ввод версии"
        echo
        echo "     0. Пропустить загрузку Xray"

        printf "\n  Введите порядковый номер релиза (0 - пропустить, 9 - ручной ввод): "
        read -r choice

        case "$choice" in
            [0-9]) ;;
            *) 
                printf "  ${red}Некорректный${reset} ввод. Пожалуйста, введите число\n"
                sleep 1
                continue
                ;;
        esac

        if [ "$choice" = "0" ]; then
            bypass_xray="true"
            printf "  Загрузка Xray ${yellow}пропущена${reset}\n"
            return
        fi

        if [ "$choice" = "9" ]; then
            printf "  Введите версию Xray для загрузки (например: v25.4.30): "
            read -r version_selected
            if [ -z "$version_selected" ]; then
                printf "  ${red}Ошибка${reset}: Версия не может быть пустой\n"
                sleep 1
                continue
            fi

            version_selected=$(echo "$version_selected" | sed 's/^v//')
            version_selected="v$version_selected"

        else
            version_selected=$(echo "$RELEASE_TAGS" | awk -v line="$choice" 'NR == line {print $0; exit}')
            if [ -z "$version_selected" ]; then
                printf "  Выбранный номер ${red}вне диапазона.${reset} Пожалуйста, попробуйте снова\n"
                sleep 1
                continue
            fi
            if [ "$USE_JSDELIVR" = "true" ]; then
                version_selected="v$version_selected"
            fi
        fi

        if ! _xray_build_url "$version_selected"; then
            printf "  ${red}Ошибка${reset}: Не удалось получить URL для загрузки Xray\n"
            exit 1
        fi
        mkdir -p "$xtmp_dir"

        printf "  ${yellow}Проверка${reset} доступности версии $version_selected...\n"

        probe_with_mirrors "$download_url"
        _rc=$?
        case "$_rc" in
            0)
                printf "  Файл ${green}доступен${reset}\n"
                ;;
            2)
                case "$_last_http" in
                    403) printf "  ${red}Доступ запрещен${reset} (403)\n" ;;
                    404) printf "  Файл ${red}не найден${reset} (404)\n" ;;
                    *)   printf "  ${yellow}Проблема с доступом${reset} (HTTP: %s)\n" "$_last_http" ;;
                esac
                printf "  ${red}Ошибка${reset}: Версия $version_selected недоступна\n"
                continue
                ;;
            *)
                if [ "$_last_curl_rc" = "28" ]; then  # curl OPERATION_TIMEDOUT
                    printf "  ${red}Таймаут${reset} при проверке\n"
                elif [ "$_last_curl_rc" != "0" ]; then
                    printf "  ${red}Ошибка curl (%s)${reset} при проверке\n" "$_last_curl_rc"
                elif [ -n "$_last_http" ] && [ "$_last_http" != "000" ]; then
                    printf "  ${yellow}Проблема с доступом${reset} (HTTP: %s)\n" "$_last_http"
                else
                    printf "  ${red}Нет соединения${reset}\n"
                fi
                printf "  ${red}Ошибка${reset}: Версия $version_selected недоступна\n"
                continue
                ;;
        esac

        printf "  ${yellow}Выполняется загрузка${reset} выбранной версии Xray\n"

        local menu_attempt=1
        local menu_success=1

        while [ "$menu_attempt" -le "$max_attempts" ]; do
            if [ "$max_attempts" -gt 1 ]; then
                printf "  Загрузка Xray (Попытка %d из %d)...\n" "$menu_attempt" "$max_attempts"
            fi

            if fetch_with_mirrors "$download_url" "$xtmp_dir/xray.$extension" 1024; then
                menu_success=0
                break
            fi

            if [ "$menu_attempt" -lt "$max_attempts" ]; then
                printf "  ${yellow}Предупреждение${reset}: Не удалось загрузить Xray. Повтор через %d сек...\n" "$delay"
                sleep "$delay"
            fi
            menu_attempt=$((menu_attempt + 1))
        done

        if [ "$menu_success" -ne 0 ]; then
            if [ "$max_attempts" -gt 1 ]; then
                printf "  ${red}Ошибка${reset}: Не удалось загрузить Xray $version_selected после %d попыток\n" "$max_attempts"
            else
                printf "  ${red}Ошибка${reset}: Не удалось загрузить Xray $version_selected\n"
            fi
            continue
        fi

        printf "  Xray ${green}успешно загружен${reset}\n"
        return 0
    done
}