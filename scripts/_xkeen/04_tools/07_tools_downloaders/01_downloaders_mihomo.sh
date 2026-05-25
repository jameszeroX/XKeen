# Загрузка Mihomo
download_mihomo() {
    USE_JSDELIVR=""
    printf "\n  ${green}Запрос информации${reset} о релизах ${yellow}Mihomo${reset}\n"

    # Получаем список релизов через GitHub API
    RELEASE_TAGS=$(curl_with_timeout -s "${mihomo_api_url}?per_page=20" 2>/dev/null | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 8)

    if [ -z "$RELEASE_TAGS" ]; then
        echo
        printf "  ${red}Нет доступа${reset} к ${yellow}GitHub API${reset}. Пробуем ${yellow}jsDelivr${reset}...\n"

        # Получаем список релизов через jsDelivr
        RELEASE_TAGS=$(curl_with_timeout -s "$mihomo_jsd_url" 2>/dev/null | jq -r '.versions[]' | head -n 8)

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

    # Инициализация переменных для повторов загрузки
    local max_attempts=1
    if [ -n "$retries_download" ] && [ "$retries_download" -gt 1 ] 2>/dev/null; then
        max_attempts=$retries_download
    fi
    local delay=${retry_delay_download:-2}

    while true; do
        echo
        echo "$RELEASE_TAGS" | awk '{printf "    %2d. %s\n", NR, $0}'
        echo
        echo "     9. Ручной ввод версии"
        echo
        echo "     0. Пропустить загрузку Mihomo"

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
            bypass_mihomo="true"
            printf "  Загрузка Mihomo ${yellow}пропущена${reset}\n"
            return
        fi

        if [ "$choice" = "9" ]; then
            printf "  Введите версию Mihomo для загрузки (например: v1.19.6): "
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

        VERSION_ARG="$version_selected"

        URL_BASE="${mihomo_gz_url}/$VERSION_ARG"

        yq_download_base_url="$(get_yq_dist_url)"

        case $architecture in
            "arm64-v8a")
                download_url="$URL_BASE/mihomo-linux-arm64-$VERSION_ARG.gz"
                download_yq="$yq_download_base_url/yq_linux_arm64"
            ;;
            "mips32le")
                if [ "$softfloat" = "true" ]; then
                    download_url="$URL_BASE/mihomo-linux-mipsle-softfloat-$VERSION_ARG.gz"
                else
                    download_url="$URL_BASE/mihomo-linux-mipsle-hardfloat-$VERSION_ARG.gz"
                fi
                download_yq="$yq_download_base_url/yq_linux_mipsle"
            ;;
            "mips32")
                download_url="$URL_BASE/mihomo-linux-mips-hardfloat-$VERSION_ARG.gz"
                download_yq="$yq_download_base_url/yq_linux_mips"
            ;;
            *)
                download_url=
                download_yq=
            ;;
        esac

        if [ -z "$download_url" ] || [ -z "$download_yq" ]; then
            printf "  ${red}Ошибка${reset}: Не удалось получить URL для загрузки Mihomo\n"
            exit 1
        fi

        filename=$(basename "$download_url")
        extension="${filename##*.}"
        mkdir -p "$mtmp_dir"
        yq_available="false"

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
                printf "  ${red}Ошибка${reset}: Версия Mihomo $version_selected недоступна\n"
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
                printf "  ${red}Ошибка${reset}: Версия Mihomo $version_selected недоступна\n"
                continue
                ;;
        esac

        printf "  ${yellow}Выполняется загрузка${reset} парсера конфигурационных файлов Mihomo - Yq\n"

        if probe_with_mirrors "$download_yq"; then
            local yq_attempt=1
            local yq_success=1

            while [ "$yq_attempt" -le "$max_attempts" ]; do
                if [ "$max_attempts" -gt 1 ]; then
                    printf "  Загрузка Yq (Попытка %d из %d)...\n" "$yq_attempt" "$max_attempts"
                fi

                if fetch_with_mirrors "$download_yq" "$install_dir/yq" 1024; then
                    chmod +x "$install_dir/yq"
                    yq_available="true"
                    yq_success=0
                    printf "  Yq ${green}успешно загружен и установлен${reset}\n"
                    break
                fi

                if [ "$yq_attempt" -lt "$max_attempts" ]; then
                    printf "  ${yellow}Предупреждение${reset}: Не удалось загрузить Yq. Повтор через %d сек...\n" "$delay"
                    sleep "$delay"
                fi
                yq_attempt=$((yq_attempt + 1))
            done

            if [ "$yq_success" -ne 0 ]; then
                printf "  ${red}Ошибка${reset}: Не удалось загрузить Yq после %d попыток\n" "$max_attempts"
            fi
        else
            printf "  ${yellow}Предупреждение${reset}: Yq недоступен для загрузки, продолжение без него\n"
        fi

        printf "  ${yellow}Выполняется загрузка${reset} выбранной версии Mihomo\n"

        if [ "$yq_available" != "true" ] && [ -x "$install_dir/yq" ]; then
            yq_available="true"
            printf "  ${yellow}Используется${reset} уже установленный Yq\n"
        fi

        if [ "$yq_available" != "true" ]; then
            printf "  ${red}Ошибка${reset}: Для работы Mihomo требуется Yq. Установка прервана\n"
            return 1
        fi

        local mihomo_attempt=1
        local mihomo_success=1

        while [ "$mihomo_attempt" -le "$max_attempts" ]; do
            if [ "$max_attempts" -gt 1 ]; then
                printf "  Загрузка Mihomo (Попытка %d из %d)...\n" "$mihomo_attempt" "$max_attempts"
            fi

            if fetch_with_mirrors "$download_url" "$mtmp_dir/mihomo.$extension" 1024; then
                mihomo_success=0
                break
            fi

            if [ "$mihomo_attempt" -lt "$max_attempts" ]; then
                printf "  ${yellow}Предупреждение${reset}: Не удалось загрузить Mihomo. Повтор через %d сек...\n" "$delay"
                sleep "$delay"
            fi
            mihomo_attempt=$((mihomo_attempt + 1))
        done

        if [ "$mihomo_success" -ne 0 ]; then
            if [ "$max_attempts" -gt 1 ]; then
                printf "  ${red}Ошибка${reset}: Не удалось загрузить Mihomo $version_selected после %d попыток\n" "$max_attempts"
            else
                printf "  ${red}Ошибка${reset}: Не удалось загрузить Mihomo $version_selected\n"
            fi
            continue
        fi

        printf "  Mihomo ${green}успешно загружен${reset}\n"
        return 0
    done
}
