# Загрузка Xray
download_xray() {
    while true; do
        printf "  ${green}Запрос информации${reset} о релизах ${yellow}Xray${reset}\n"
        
        # Получаем список релизов через GitHub API
        RELEASE_TAGS=$(curl --connect-timeout 10 -s "${xray_api_url}?per_page=20" 2>/dev/null | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 8)
        
        if [ -z "$RELEASE_TAGS" ]; then
            echo
            printf "  ${red}Нет доступа${reset} к ${yellow}GitHub API${reset}. Пробуем ${yellow}jsDelivr${reset}...\n"
            
            # Получаем список релизов через jsDelivr
            RELEASE_TAGS=$(curl --connect-timeout 10 -m 60 -s "$xray_jsd_url" 2>/dev/null | jq -r '.versions[]' | head -n 8)
            
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

        if [ -z "$USE_JSDELIVR" ]; then
            VERSION_ARG="$version_selected"
        else
            VERSION_ARG="$version_selected"
            unset USE_JSDELIVR
        fi

        URL_BASE="${xray_zip_url}/$VERSION_ARG"

        case $architecture in
            "arm64-v8a") download_url="$URL_BASE/Xray-linux-arm64-v8a.zip" ;;
            "mips32le") download_url="$URL_BASE/Xray-linux-mips32le.zip" ;;
            "mips32") download_url="$URL_BASE/Xray-linux-mips32.zip" ;;
            "mips64") download_url="$URL_BASE/Xray-linux-mips64.zip" ;;
            "mips64le") download_url="$URL_BASE/Xray-linux-mips64le.zip" ;;
            "arm32-v5") download_url="$URL_BASE/Xray-linux-arm32-v5.zip" ;;
            *) download_url= ;;
        esac

        if [ -z "$download_url" ]; then
            printf "  ${red}Ошибка${reset}: Не удалось получить URL для загрузки Xray\n"
            exit 1
        fi

        filename=$(basename "$download_url")
        extension="${filename##*.}"
        xray_dist=$(mktemp)
        mkdir -p "$xtmp_dir"

        if [ "$use_direct" != "true" ]; then
            download_url="$gh_proxy/$download_url"
        fi

        printf "  ${yellow}Проверка${reset} доступности версии $version_selected...\n"

        check_url_availability() {
            url=$1
            timeout=$2

            http_status=$(curl --connect-timeout "$timeout" -m 60 \
                              -I \
                              -s \
                              -L \
                              -w "%{http_code}" \
                              -o /dev/null \
                              "$url" 2>/dev/null)
            curl_exit_code=$?

            if [ "$curl_exit_code" -eq 0 ] && [ "$http_status" = "405" ]; then
                http_status=$(curl --connect-timeout "$timeout" -m 60 \
                                  -s \
                                  -L \
                                  -r 0-0 \
                                  -w "%{http_code}" \
                                  -o /dev/null \
                                  "$url" 2>/dev/null)
                curl_exit_code=$?
            fi

            if [ "$curl_exit_code" -eq 28 ]; then
                printf "  ${red}Таймаут${reset} при проверке\n"
                return 1
            elif [ "$curl_exit_code" -ne 0 ]; then
                printf "  ${red}Ошибка curl ($curl_exit_code)${reset} при проверке\n"
                return 1
            fi

            case "$http_status" in
                2[0-9][0-9])
                    printf "  Файл ${green}доступен${reset} (HTTP $http_status)\n"
                    return 0
                    ;;
                404)
                    printf "  Файл ${red}не найден${reset} (404)\n"
                    return 2
                    ;;
                403)
                    printf "  ${red}Доступ запрещен${reset} (403)\n"
                    return 2
                    ;;
                000)
                    printf "  ${red}Нет соединения${reset}\n"
                    return 1
                    ;;
                *)
                    printf "  ${yellow}Проблема с доступом${reset} (HTTP: $http_status)\n"
                    return 1
                    ;;
            esac
        }

        # Проверка доступности версии
        if ! check_url_availability "$download_url" 10; then
            rm -f "$xray_dist"
            printf "  ${red}Ошибка${reset}: Версия $version_selected недоступна\n"
            continue
        fi

        printf "  ${yellow}Выполняется загрузка${reset} выбранной версии Xray\n"

        # Загрузка Xray
        if curl --connect-timeout 10 -m 60 \
               -fL \
               -o "$xray_dist" \
               "$download_url" 2>/dev/null; then

            if [ -s "$xray_dist" ]; then
                if head -c 100 "$xray_dist" 2>/dev/null | grep -iq "<!DOCTYPE html\|<html\|Error\|404\|Not Found"; then
                    rm -f "$xray_dist"
                    printf "  ${red}Ошибка${reset}: Получена HTML страница ошибки вместо файла\n"
                    continue
                fi

                mv "$xray_dist" "$xtmp_dir/xray.$extension"
                printf "  Xray ${green}успешно загружен${reset}\n"
                return 0
            else
                rm -f "$xray_dist"
                printf "  ${red}Ошибка${reset}: Загруженный файл Xray поврежден\n"
                continue
            fi
        else
            rm -f "$xray_dist"
            printf "  ${red}Ошибка${reset}: Не удалось загрузить Xray $version_selected\n"
            continue
        fi
    done
}