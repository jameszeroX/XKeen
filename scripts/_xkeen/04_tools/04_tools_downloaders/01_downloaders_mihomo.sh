# Загрузка Mihomo
download_mihomo() {
    while true; do
        printf "  ${green}Запрос информации${reset} о релизах ${yellow}Mihomo${reset}\n"
        RELEASE_TAGS=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases?per_page=20 | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 9) >/dev/null 2>&1

        if [ -z "$RELEASE_TAGS" ]; then
            echo ""
            printf "  ${red}Нет доступа${reset} к ${yellow}GitHub API${reset}. Пробуем ${yellow}jsDelivr${reset}...\n"
            RELEASE_TAGS=$(curl -s https://data.jsdelivr.com/v1/package/gh/MetaCubeX/mihomo | jq -r '.versions[]' | head -n 9) >/dev/null 2>&1
            
            if [ -z "$RELEASE_TAGS" ]; then
                echo ""
                printf "  ${red}Нет доступа${reset} к ${yellow}jsDelivr${reset}\n"
                echo ""
                printf "  ${red}Ошибка:${reset} Не удалось получить список релизов ни через ${yellow}GitHub API${reset}, ни через ${yellow}jsDelivr${reset}\n
  Проверьте соединение с интернетом или повторите позже\n"
                echo ""
                exit 1
            fi
            echo ""
            printf "  Список релизов получен с использованием ${yellow}jsDelivr${reset}:\n"
            USE_JSDELIVR="true"
        else
            echo ""
            printf "  Список релизов получен с использованием ${yellow}GitHub API${reset}:\n"
        fi

        echo "$RELEASE_TAGS" | awk '{printf "%2d) %s\n", NR, $0}'
        echo ""
        echo " 0) Пропустить загрузку Mihomo"

        printf "\n  Введите порядковый номер релиза Mihomo (или 0 для пропуска): "
        read -r choice

        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            printf "  ${red}Некорректный${reset} ввод. Пожалуйста, введите число\n"
            sleep 1
            continue
        fi

        if [ "$choice" -eq 0 ]; then
            bypass_mihomo="true"
            printf "  Загрузка Mihomo ${yellow}пропущена${reset}\n"
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
	
        URL_BASE="https://github.com/MetaCubeX/mihomo/releases/download/$VERSION_ARG"
        URL_YQ="https://github.com/mikefarah/yq/releases/latest/download"

        case $architecture in
            "arm64-v8a")
                download_url="$URL_BASE/mihomo-linux-arm64-$VERSION_ARG.gz"
                download_yq="$URL_YQ/yq_linux_arm64"
            ;;
            "mips32le")
                download_url="$URL_BASE/mihomo-linux-mipsle-hardfloat-$VERSION_ARG.gz"
                download_yq="$URL_YQ/yq_linux_mipsle"
            ;;
            "mips")
                download_url="$URL_BASE/mihomo-linux-mips-hardfloat-$VERSION_ARG.gz"
                download_yq="$URL_YQ/yq_linux_mips"
            ;;
            "mips64")
                download_url="$URL_BASE/mihomo-linux-mips64-$VERSION_ARG.gz"
                download_yq="$URL_YQ/yq_linux_mips64"
            ;;
            "mips64le")
                download_url="$URL_BASE/mihomo-linux-mips64le-$VERSION_ARG.gz"
                download_yq="$URL_YQ/yq_linux_mips64le"
            ;;
            "arm32-v5")
                download_url="$URL_BASE/mihomo-linux-armv5-$VERSION_ARG.gz"
                download_yq="$URL_YQ/yq_linux_arm"
            ;;
            *)
                download_url=""
                download_yq=""
            ;;
        esac

        if [ -z "$download_url" ] || [ -z "$download_yq" ]; then
            echo -e "  ${red}Ошибка${reset}: Не удалось получить URL для загрузки Mihomo"
            exit 1
        fi

        filename=$(basename "$download_url")
        extension="${filename##*.}"
        mkdir -p "$mtmp_dir"
        
        echo -e "  ${yellow}Выполняется загрузка${reset} выбранной версии Mihomo"
        curl -L -o "$mtmp_dir/$filename" "$download_url" &> /dev/null
        curl -L -o "$install_dir/yq" "$download_yq" &> /dev/null && chmod +x "$install_dir/yq"

        if [ -e "$mtmp_dir/$filename" ]; then
            mv "$mtmp_dir/$filename" "$mtmp_dir/mihomo.$extension"
            echo -e "  Mihomo ${green}успешно загружен${reset}"
            return
        else
            echo -e "  ${red}Ошибка${reset}: Не удалось загрузить Mihomo. Проверьте соединение с интернетом или повторите позже"
            exit 1
        fi
    done
}