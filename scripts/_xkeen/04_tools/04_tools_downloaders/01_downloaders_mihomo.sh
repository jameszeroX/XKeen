# Загрузка Mihomo
download_mihomo() {
    while true; do
        printf "  ${green}Запрос информации${reset} о релизах ${yellow}Mihomo${reset}\n"
        
        # Получаем список релизов через GitHub API
        RELEASE_TAGS=$(curl -m 10 -s "${mihomo_api_url}?per_page=20" 2>/dev/null | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 8)
        
        if [ -z "$RELEASE_TAGS" ]; then
            echo
            printf "  ${red}Нет доступа${reset} к ${yellow}GitHub API${reset}. Пробуем ${yellow}jsDelivr${reset}...\n"
            
            # Получаем список релизов через jsDelivr
            RELEASE_TAGS=$(curl -m 10 -s "$mihomo_jsd_url" 2>/dev/null | jq -r '.versions[]' | head -n 8)
            
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
        echo "     0. Пропустить загрузку Mihomo"

        printf "\n  Введите порядковый номер релиза (0 - пропустить, 9 - ручной ввод): "
        read -r choice

        if ! echo "$choice" | grep -Eq '^[0-9]$'; then
            printf "  ${red}Некорректный${reset} ввод. Пожалуйста, введите число\n"
            sleep 1
            continue
        fi

        if [ "$choice" -eq 0 ]; then
            bypass_mihomo="true"
            printf "  Загрузка Mihomo ${yellow}пропущена${reset}\n"
            return
        fi

        if [ "$choice" -eq 9 ]; then
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
            VERSION_ARG="$version_selected"
            unset USE_JSDELIVR
        fi
	
        URL_BASE="${mihomo_gz_url}/$VERSION_ARG"

        case $architecture in
            "arm64-v8a")
                download_url="$URL_BASE/mihomo-linux-arm64-$VERSION_ARG.gz"
                download_yq="$yq_dist_url/yq_linux_arm64"
            ;;
            "mips32le")
                download_url="$URL_BASE/mihomo-linux-mipsle-hardfloat-$VERSION_ARG.gz"
                download_yq="$yq_dist_url/yq_linux_mipsle"
            ;;
            "mips32")
                download_url="$URL_BASE/mihomo-linux-mips-hardfloat-$VERSION_ARG.gz"
                download_yq="$yq_dist_url/yq_linux_mips"
            ;;
            "mips64")
                download_url="$URL_BASE/mihomo-linux-mips64-$VERSION_ARG.gz"
                download_yq="$yq_dist_url/yq_linux_mips64"
            ;;
            "mips64le")
                download_url="$URL_BASE/mihomo-linux-mips64le-$VERSION_ARG.gz"
                download_yq="$yq_dist_url/yq_linux_mips64le"
            ;;
            "arm32-v5")
                download_url="$URL_BASE/mihomo-linux-armv5-$VERSION_ARG.gz"
                download_yq="$yq_dist_url/yq_linux_arm"
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
        yq_dist=$(mktemp)
        mihomo_dist=$(mktemp)
        mkdir -p "$mtmp_dir"

        echo -e "  ${yellow}Проверка${reset} доступности версии $version_selected..."

        # Функция для проверки доступности
        check_url_availability() {
            url=$1
            timeout=$2
            description=$3

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
            if ! check_url_availability "$download_url" 10 "GitHub"; then
                rm -f "$xray_dist"
                echo -e "  ${red}Ошибка${reset}: Версия $version_selected недоступна"
                continue
            fi
        else
            if ! check_url_availability "$download_url" 10 "jsDelivr"; then
                rm -f "$xray_dist"
                echo -e "  ${red}Ошибка${reset}: Версия $version_selected недоступна"
                continue
            fi
        fi

        printf "  ${yellow}Выполняется загрузка${reset} парсера конфигурационных файлов Mihomo - Yq\n"

        if [ "$use_direct" = "true" ]; then
            :
        else
            download_yq="$gh_proxy/$download_yq"
        fi

        if curl -m 10 -L "$download_yq" -o "$yq_dist" 2>/dev/null; then
            if [ -s "$yq_dist" ]; then
                mv "$yq_dist" "$install_dir/yq"
                chmod +x "$install_dir/yq"
                printf "  Yq ${green}успешно загружен и установлен${reset}\n"
            else
                printf "  ${red}Ошибка${reset}: Загруженный файл Yq поврежден\n"
            fi
        else
            printf "  ${red}Ошибка${reset}: Не удалось загрузить Yq\n"
        fi

        printf "  ${yellow}Выполняется загрузка${reset} выбранной версии Mihomo\n"

        if [ "$use_direct" = "true" ]; then
            :
        else
            download_url="$gh_proxy/$download_url"
        fi

        if curl -m 10 -L "$download_url" -o "$mihomo_dist" 2>/dev/null; then
            if [ -s "$mihomo_dist" ]; then
                mv "$mihomo_dist" "$mtmp_dir/mihomo.$extension"
                printf "  Mihomo ${green}успешно загружен${reset}\n"
                return 0
            else
                rm -f "$mihomo_dist"
                printf "  ${red}Ошибка${reset}: Загруженный файл Mihomo поврежден\n"
                continue
            fi
        else
            rm -f "$mihomo_dist"
            printf "  ${red}Ошибка${reset}: Не удалось загрузить Mihomo $version_selected\n"
            continue
        fi
    done
}