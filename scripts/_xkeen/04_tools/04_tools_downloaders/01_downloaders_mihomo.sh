# Загрузка Mihomo
download_mihomo() {
    while true; do
        printf "  ${green}Запрос информации${reset} о релизах ${yellow}Mihomo${reset}\n"
        RELEASE_TAGS=$(curl -s ${mihomo_api_url}?per_page=20 | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 8) >/dev/null 2>&1

        if [ -z "$RELEASE_TAGS" ]; then
            echo
            printf "  ${red}Нет доступа${reset} к ${yellow}GitHub API${reset}. Пробуем ${yellow}jsDelivr${reset}...\n"
            RELEASE_TAGS=$(curl -s $mihomo_jsd_url | jq -r '.versions[]' | head -n 8) >/dev/null 2>&1
            
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

        if [ -z $USE_JSDELIVR ]; then
            VERSION_ARG="$version_selected"
        else
            VERSION_ARG=v"$version_selected"
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
            echo -e "  ${red}Ошибка${reset}: Не удалось получить URL для загрузки Mihomo"
            exit 1
        fi

        filename=$(basename "$download_url")
        extension="${filename##*.}"
        yq_dist=$(mktemp)
        mihomo_dist=$(mktemp)
        mkdir -p "$mtmp_dir"

        echo -e "  ${yellow}Проверка${reset} доступности версии $version_selected..."
        http_status=$(curl -L -s -o /dev/null -w "%{http_code}" "$download_url")

        if [ "$http_status" -eq 404 ]; then
            echo -e "  ${red}Ошибка${reset}: Версия $version_selected не существует или не поддерживает архитектуру $architecture"
            echo -e "  Проверьте правильность введенной версии и поддерживаемые архитектуры"
            rm -f "$mihomo_dist" "$yq_dist"
            sleep 2
            continue
        elif [ "$http_status" -ne 200 ]; then
            echo -e "  ${red}Ошибка${reset}: Проблема с доступом к серверу (HTTP статус: $http_status)"
            rm -f "$mihomo_dist" "$yq_dist"
            sleep 2
            continue
        fi

        echo -e "  ${yellow}Проверка${reset} доступности Yq для архитектуры $architecture..."
        yq_http_status=$(curl -L -s -o /dev/null -w "%{http_code}" "$download_yq")

        if [ "$yq_http_status" -eq 404 ]; then
            echo -e "  ${red}Ошибка${reset}: Yq не поддерживает архитектуру $architecture"
            rm -f "$mihomo_dist" "$yq_dist"
            sleep 2
            continue
        elif [ "$yq_http_status" -ne 200 ]; then
            echo -e "  ${yellow}Предупреждение${reset}: Проблема с доступом к Yq (HTTP статус: $yq_http_status)"
            echo -e "  Продолжаем загрузку, но Yq может быть недоступен"
        fi

        # Загрузка Yq (с попыткой через прокси)
        echo -e "  ${yellow}Выполняется загрузка${reset} парсера конфигурационных файлов Mihomo - Yq"
        if curl -L -o "$yq_dist" "$download_yq" &> /dev/null; then
            if [ -s "$yq_dist" ]; then
                mv "$yq_dist" "$install_dir/yq"
                chmod +x "$install_dir/yq"
                echo -e "  Yq ${green}успешно загружен${reset}"
            else
                echo -e "  ${red}Ошибка${reset}: Загруженный файл Yq поврежден"
            fi
        else
            if curl -L -o "$yq_dist" "$gh_proxy/$download_yq" &> /dev/null; then
                if [ -s "$yq_dist" ]; then
                    mv "$yq_dist" "$install_dir/yq"
                    chmod +x "$install_dir/yq"
                    echo -e "  Yq ${green}успешно загружен через прокси${reset}"
                else
                    echo -e "  ${red}Ошибка${reset}: Загруженный файл Yq поврежден"
                fi
            else
                echo -e "  ${red}Ошибка${reset}: Не удалось загрузить Yq. Проверьте соединение с интернетом или повторите позже"
            fi
        fi

        # Загрузка Mihomo (с попыткой через прокси)
        echo -e "  ${yellow}Выполняется загрузка${reset} выбранной версии Mihomo"
        if curl -L -o "$mihomo_dist" "$download_url" &> /dev/null; then
            if [ -s "$mihomo_dist" ]; then
                mv "$mihomo_dist" "$mtmp_dir/mihomo.$extension"
                echo -e "  Mihomo ${green}успешно загружен${reset}"
                return 0
            else
                echo -e "  ${red}Ошибка${reset}: Загруженный файл Mihomo поврежден"
            fi
        else
            if curl -L -o "$mihomo_dist" "$gh_proxy/$download_url" &> /dev/null; then
                if [ -s "$mihomo_dist" ]; then
                    mv "$mihomo_dist" "$mtmp_dir/mihomo.$extension"
                    echo -e "  Mihomo ${green}успешно загружен через прокси${reset}"
                    return 0
                else
                    echo -e "  ${red}Ошибка${reset}: Загруженный файл Mihomo поврежден"
                fi
            else
                echo -e "  ${red}Ошибка${reset}: Не удалось загрузить Mihomo. Проверьте:"
                echo -e "  - Существование версии $version_selected"
                echo -e "  - Поддержку архитектуры $architecture"
                echo -e "  - Соединение с интернетом"
            fi
        fi

        rm -f "$yq_dist" "$mihomo_dist"
        echo -e "  ${yellow}Пожалуйста, попробуйте другую версию${reset}"
        sleep 2
        continue
    done
}