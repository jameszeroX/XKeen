# Загрузка Xray
download_xray() {
    USE_JSDELIVR=""
    printf "  ${green}Запрос информации${reset} о релизах ${yellow}Xray${reset}\n"

    # Получаем список релизов через GitHub API
    RELEASE_TAGS=$(eval curl $curl_extra --connect-timeout 10 $curl_timeout -s "${xray_api_url}?per_page=50" 2>/dev/null | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 8)

    if [ -z "$RELEASE_TAGS" ]; then
        echo
        printf "  ${red}Нет доступа${reset} к ${yellow}GitHub API${reset}. Пробуем ${yellow}jsDelivr${reset}...\n"

        # Получаем список релизов через jsDelivr
        RELEASE_TAGS=$(eval curl $curl_extra --connect-timeout 10 $curl_timeout -s "$xray_jsd_url" 2>/dev/null | jq -r '.versions[]' | head -n 8)

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

    if [ "$autoinstall_mode" = "true" ]; then
        version_selected=$(echo "$RELEASE_TAGS" | head -1)
        [ "$USE_JSDELIVR" = "true" ] && version_selected="v$version_selected"
        printf "  ${green}Авто-режим${reset}: выбрана последняя версия ${yellow}%s${reset}\n" "$version_selected"

        VERSION_ARG="$version_selected"
        URL_BASE="${xray_zip_url}/$VERSION_ARG"

        case $architecture in
            "arm64-v8a") download_url="$URL_BASE/Xray-linux-arm64-v8a.zip" ;;
            "mips32le")  download_url="$URL_BASE/Xray-linux-mips32le.zip" ;;
            "mips32")    download_url="$URL_BASE/Xray-linux-mips32.zip" ;;
            *)           download_url= ;;
        esac

        if [ -z "$download_url" ]; then
            printf "  ${red}Ошибка${reset}: Не удалось получить URL для загрузки Xray\n"
            exit 1
        fi

        filename=$(basename "$download_url")
        extension="${filename##*.}"
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

        if ! fetch_with_mirrors "$download_url" "$xtmp_dir/xray.$extension" 1024; then
            printf "  ${red}Ошибка${reset}: Не удалось загрузить Xray %s\n" "$version_selected"
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

        VERSION_ARG="$version_selected"

        URL_BASE="${xray_zip_url}/$VERSION_ARG"

        case $architecture in
            "arm64-v8a") download_url="$URL_BASE/Xray-linux-arm64-v8a.zip" ;;
            "mips32le") download_url="$URL_BASE/Xray-linux-mips32le.zip" ;;
            "mips32") download_url="$URL_BASE/Xray-linux-mips32.zip" ;;
            *) download_url= ;;
        esac

        if [ -z "$download_url" ]; then
            printf "  ${red}Ошибка${reset}: Не удалось получить URL для загрузки Xray\n"
            exit 1
        fi

        filename=$(basename "$download_url")
        extension="${filename##*.}"
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

        if ! fetch_with_mirrors "$download_url" "$xtmp_dir/xray.$extension" 1024; then
            printf "  ${red}Ошибка${reset}: Не удалось загрузить Xray $version_selected\n"
            continue
        fi
        printf "  Xray ${green}успешно загружен${reset}\n"
        return 0
    done
}
