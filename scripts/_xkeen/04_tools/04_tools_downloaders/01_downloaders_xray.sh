# Загрузка Xray
download_xray() {
    while true; do
        printf "  ${green}Запрос информации${reset} о релизах ${yellow}Xray${reset}\n"
        RELEASE_TAGS=$(curl -m 10 -s ${xray_api_url}?per_page=20 | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 8) >/dev/null 2>&1

        if [ -z "$RELEASE_TAGS" ]; then
            echo
            printf "  ${red}Нет доступа${reset} к ${yellow}GitHub API${reset}. Пробуем ${yellow}jsDelivr${reset}...\n"
            RELEASE_TAGS=$(curl -m 10 -s $xray_jsd_url | jq -r '.versions[]' | head -n 8) >/dev/null 2>&1
            
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

        if ! echo "$choice" | grep -Eq '^[0-9]$'; then
            printf "  ${red}Некорректный${reset} ввод. Пожалуйста, введите число\n"
            sleep 1
            continue
        fi

        if [ "$choice" -eq 0 ]; then
            bypass_xray="true"
            printf "  Загрузка Xray ${yellow}пропущена${reset}\n"
            return
        fi

        if [ "$choice" -eq 9 ]; then
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
            version_selected=$(echo "$RELEASE_TAGS" | sed -n "${choice}p")
            if [ -z "$version_selected" ]; then
                printf "  Выбранный номер ${red}вне диапазона.${reset} Пожалуйста, попробуйте снова\n"
                sleep 1
                continue
            fi
        fi

        if [ -z "$USE_JSDELIVR" ]; then
            VERSION_ARG="$version_selected"
        else
            VERSION_ARG=v"$version_selected"
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
            echo -e "  ${red}Ошибка${reset}: Не удалось получить URL для загрузки Xray"
            exit 1
        fi

        filename=$(basename "$download_url")
        extension="${filename##*.}"
        xray_dist=$(mktemp)
        mkdir -p "$xtmp_dir"
        
        echo -e "  ${yellow}Проверка${reset} доступности версии $version_selected..."
        
        # Функция для проверки доступности
        check_url_availability() {
            local url=$1
            local timeout=$2
            local description=$3

            echo -e "  ${yellow}Проверка через $description...${reset}"
            http_status=$(curl -m $timeout -L -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
            curl_exit_code=$?

            if [ $curl_exit_code -eq 28 ]; then
                echo -e "  ${red}Таймаут${reset} при проверке через $description"
                return 1
            elif [ $curl_exit_code -ne 0 ]; then
                echo -e "  ${red}Ошибка curl ($curl_exit_code)${reset} при проверке через $description"
                return 1
            elif [ "$http_status" -eq 200 ]; then
                echo -e "  Версия ${green}доступна через $description${reset}"
                return 0
            elif [ "$http_status" -eq 404 ]; then
                echo -e "  ${red}Версия не найдена${reset} через $description (404)"
                return 2
            else
                echo -e "  ${yellow}Проблема с доступом${reset} через $description (HTTP: $http_status)"
                return 1
            fi
        }

        # Проверка доступности версии
        if [ -z "$USE_JSDELIVR" ]; then
            if check_url_availability "$download_url" 10 "GitHub"; then
                USE_DIRECT="true"
            else
                echo -e "  ${yellow}Пробуем проверить через прокси...${reset}"
                if check_url_availability "$gh_proxy/$download_url" 10 "прокси"; then
                    USE_PROXY="true"
                else
                    echo -e "  ${red}Ошибка${reset}: Версия $version_selected недоступна ни напрямую, ни через прокси"
                    echo -e "  Возможные причины:"
                    echo -e "  - Версия $version_selected не существует"
                    echo -e "  - Архитектура $architecture не поддерживается"
                    echo -e "  - Проблемы с сетью"
                    rm -f "$xray_dist"
                    sleep 2
                    continue
                fi
            fi
        else
            if ! check_url_availability "$download_url" 10 "jsDelivr"; then
                echo -e "  ${red}Ошибка${reset}: Версия $version_selected недоступна через jsDelivr"
                rm -f "$xray_dist"
                sleep 2
                continue
            fi
            USE_DIRECT="true"
        fi

        # Функция для загрузки
        download_with_retry() {
            local url=$1
            local description=$2
            local max_attempts=2

            for attempt in $(seq 1 $max_attempts); do
                echo -e "  ${yellow}Попытка загрузки $attempt/$max_attempts через $description...${reset}"

                if curl -m 10 -L -o "$xray_dist" "$url" 2>/dev/null; then
                    if [ -s "$xray_dist" ]; then
                        echo -e "  Xray ${green}успешно загружен через $description${reset}"
                        return 0
                    else
                        echo -e "  ${red}Ошибка${reset}: Загруженный файл Xray поврежден (пустой)"
                        rm -f "$xray_dist"
                        xray_dist=$(mktemp)
                    fi
                else
                    echo -e "  ${red}Ошибка загрузки${reset} через $description (попытка $attempt/$max_attempts)"
                fi
                
                if [ $attempt -lt $max_attempts ]; then
                    echo -e "  ${yellow}Повторная попытка через 2 секунды...${reset}"
                    sleep 2
                fi
            done
            return 1
        }

        echo -e "  ${yellow}Выполняется загрузка${reset} выбранной версии Xray"
        
        if [ "$USE_PROXY" = "true" ]; then
            if download_with_retry "$gh_proxy/$download_url" "прокси"; then
                mv "$xray_dist" "$xtmp_dir/xray.$extension"
                unset USE_PROXY
                return 0
            fi
        else
            if download_with_retry "$download_url" "прямое соединение"; then
                mv "$xray_dist" "$xtmp_dir/xray.$extension"
                return 0
            else
                echo -e "  ${yellow}Пробуем загрузку через прокси...${reset}"
                if download_with_retry "$gh_proxy/$download_url" "прокси"; then
                    mv "$xray_dist" "$xtmp_dir/xray.$extension"
                    return 0
                fi
            fi
        fi
        
        # Если все попытки загрузки не удались
        rm -f "$xray_dist"
        echo -e "  ${red}Ошибка${reset}: Не удалось загрузить Xray после всех попыток. Проверьте:"
        echo -e "  - Существование версии $version_selected"
        echo -e "  - Поддержку архитектуры $architecture"
        echo -e "  - Соединение с интернетом"
        echo -e "  ${yellow}Пожалуйста, попробуйте другую версию${reset}"
        sleep 2
        continue
    done
}