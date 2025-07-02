# Загрузка Mihomo
download_mihomo() {
    while true; do
        printf "  ${green}Запрос информации${reset} о релизах ${yellow}Mihomo${reset}\n"
        RELEASE_TAGS=$(curl -s ${mihomo_api_url}?per_page=20 | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 9) >/dev/null 2>&1

        if [ -z "$RELEASE_TAGS" ]; then
            echo ""
            printf "  ${red}Нет доступа${reset} к ${yellow}GitHub API${reset}. Пробуем ${yellow}jsDelivr${reset}...\n"
            RELEASE_TAGS=$(curl -s $mihomo_jsd_url | jq -r '.versions[]' | head -n 9) >/dev/null 2>&1
            
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

        echo ""
        echo "$RELEASE_TAGS" | awk '{printf "    %2d. %s\n", NR, $0}'
        echo ""
        echo "     0. Пропустить загрузку Mihomo"

        printf "\n  Введите порядковый номер релиза Mihomo (или 0 для пропуска): "
        read -r choice

        if ! echo "$choice" | grep -Eq '^[0-9]+$'; then
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
        yq_dist=$(mktemp)
        mihomo_dist=$(mktemp)
        mkdir -p "$mtmp_dir"

        echo -e "  ${yellow}Выполняется загрузка${reset} парсера конфигурационных файлов Mihomo - yq"
        if curl -L -o "$yq_dist" "$download_yq" &> /dev/null; then
            if [ -s "$yq_dist" ]; then
                mv "$yq_dist" "$install_dir/yq"
                chmod +x "$install_dir/yq"
                echo -e "  yq ${green}успешно загружен${reset}"
            else
                echo -e "  ${red}Ошибка${reset}: Загруженный файл yq поврежден"
            fi
        else
            echo -e "  ${red}Ошибка${reset}: Не удалось загрузить yq. Проверьте соединение с интернетом или повторите позже"
        fi

        echo -e "  ${yellow}Выполняется загрузка${reset} выбранной версии Mihomo"
        if curl -L -o "$mihomo_dist" "$download_url" &> /dev/null; then
            if [ -s "$mihomo_dist" ]; then
                mv "$mihomo_dist" "$mtmp_dir/mihomo.$extension"
                echo -e "  Mihomo ${green}успешно загружен${reset}"
                return
            else
                echo -e "  ${red}Ошибка${reset}: Загруженный файл Mihomo поврежден"
            fi
        else
            echo -e "  ${red}Ошибка${reset}: Не удалось загрузить Mihomo. Проверьте соединение с интернетом или повторите позже"
            rm -f "$mihomo_dist" "$yq_dist"
            exit 1
        fi

        rm -f "$yq_dist" "$mihomo_dist"
        exit 1
    done
}