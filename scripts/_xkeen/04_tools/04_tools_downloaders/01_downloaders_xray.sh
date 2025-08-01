# Загрузка Xray
download_xray() {
    while true; do
        printf "  ${green}Запрос информации${reset} о релизах ${yellow}Xray${reset}\n"
        RELEASE_TAGS=$(curl -s ${xray_api_url}?per_page=20 | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 9) >/dev/null 2>&1

        if [ -z "$RELEASE_TAGS" ]; then
            echo
            printf "  ${red}Нет доступа${reset} к ${yellow}GitHub API${reset}. Пробуем ${yellow}jsDelivr${reset}...\n"
            RELEASE_TAGS=$(curl -s $xray_jsd_url | jq -r '.versions[]' | head -n 9) >/dev/null 2>&1
            
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
        echo "     0. Пропустить загрузку Xray"

        printf "\n  Введите порядковый номер релиза Xray (или 0 для пропуска): "
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

        version_selected=$(echo "$RELEASE_TAGS" | sed -n "${choice}p")
        if [ -z "$version_selected" ]; then
            printf "  Выбранный номер ${red}вне диапазона.${reset} Пожалуйста, попробуйте снова\n"
            sleep 1
            continue
        fi

        if [ -z $USE_JSDELIVR ]; then
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

        echo -e "  ${yellow}Выполняется загрузка${reset} выбранной версии Xray"
        if curl -L -o "$xray_dist" "$download_url" &> /dev/null; then
            if [ -s "$xray_dist" ]; then
                mv "$xray_dist" "$xtmp_dir/xray.$extension"
                echo -e "  Xray ${green}успешно загружен${reset}"
                return 0
            else
                echo -e "  ${red}Ошибка${reset}: Загруженный файл Xray поврежден"
            fi
        else
            # Попытка загрузить через прокси, если прямая загрузка не удалась
            if curl -L -o "$xray_dist" "$gh_proxy/$download_url" &> /dev/null; then
                if [ -s "$xray_dist" ]; then
                    mv "$xray_dist" "$xtmp_dir/xray.$extension"
                    echo -e "  Xray ${green}успешно загружен через прокси${reset}"
                    return 0
                else
                    echo -e "  ${red}Ошибка${reset}: Загруженный файл Xray поврежден"
                fi
            else
                    echo -e "  ${red}Ошибка${reset}: Не удалось загрузить Xray. Проверьте соединение с интернетом или повторите позже"
            fi
        fi
        rm -f "$xray_dist"
        exit 1
    done
}