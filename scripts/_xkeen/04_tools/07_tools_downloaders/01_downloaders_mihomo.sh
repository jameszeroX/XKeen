# Загрузка Mihomo
download_mihomo() {
    test_github

    check_url_availability() {
        url=$1
        timeout=$2

        http_status=$(curl --connect-timeout "$timeout" $curl_timeout \
                          -I \
                          -s \
                          -L \
                          -w "%{http_code}" \
                          -o /dev/null \
                          "$url" 2>/dev/null)
        curl_exit_code=$?

        if [ "$curl_exit_code" -eq 0 ] && [ "$http_status" = "405" ]; then
            http_status=$(curl --connect-timeout "$timeout" $curl_timeout \
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
                printf "  Файл ${green}доступен${reset}\n"
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

    USE_JSDELIVR=""
    printf "  ${green}Запрос информации${reset} о релизах ${yellow}Mihomo${reset}\n"

    # Получаем список релизов через GitHub API
    RELEASE_TAGS=$(curl --connect-timeout 10 $curl_timeout -s "${mihomo_api_url}?per_page=20" 2>/dev/null | jq -r '.[] | select(.prerelease == false) | .tag_name' | head -n 8)

    if [ -z "$RELEASE_TAGS" ]; then
        echo
        printf "  ${red}Нет доступа${reset} к ${yellow}GitHub API${reset}. Пробуем ${yellow}jsDelivr${reset}...\n"

        # Получаем список релизов через jsDelivr
        RELEASE_TAGS=$(curl --connect-timeout 10 $curl_timeout -s "$mihomo_jsd_url" 2>/dev/null | jq -r '.versions[]' | head -n 8)

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
                download_url="$URL_BASE/mihomo-linux-mipsle-hardfloat-$VERSION_ARG.gz"
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
        yq_dist=$(mktemp "$mtmp_dir/yq.XXXXXX")
        mihomo_dist=$(mktemp "$mtmp_dir/mihomo.XXXXXX")
        yq_available="false"

        if [ "$use_direct" != "true" ]; then
            download_url="$gh_proxy/$download_url"
            download_yq="$gh_proxy/$download_yq"
        fi

        printf "  ${yellow}Проверка${reset} доступности версии $version_selected...\n"

        # Проверка доступности версии Mihomo
        if ! check_url_availability "$download_url" 10; then
            rm -f "$mihomo_dist"
            printf "  ${red}Ошибка${reset}: Версия Mihomo $version_selected недоступна\n"
            continue
        fi

        printf "  ${yellow}Выполняется загрузка${reset} парсера конфигурационных файлов Mihomo - Yq\n"

        # Загрузка Yq
        if check_url_availability "$download_yq" 10; then
            yq_api_url=""
            if [ "$yq_use_workaround" = "true" ]; then
                yq_api_url="https://api.github.com/repos/jameszeroX/yq/releases/tags/$yq_workaround_tag"
            else
                yq_api_url="https://api.github.com/repos/mikefarah/yq/releases/latest"
            fi

            yq_expected_sha256=""
            yq_api_digest=$(curl --connect-timeout 10 $curl_timeout -s "$yq_api_url" 2>/dev/null \
                | jq -r --arg fname "$(basename "$download_yq" | sed "s|.*/||")" '.assets[] | select(.name == $fname) | .digest // empty' 2>/dev/null)
            if [ -n "$yq_api_digest" ]; then
                yq_expected_sha256=$(printf '%s' "$yq_api_digest" | sed 's/^sha256://')
            fi

            if curl --connect-timeout 10 $curl_timeout \
                   -fL \
                   -o "$yq_dist" \
                   "$download_yq" 2>/dev/null; then
                if [ -s "$yq_dist" ]; then
                    if ! verify_download_integrity "$yq_dist" "$yq_expected_sha256"; then
                        rm -f "$yq_dist"
                        printf "  ${red}Ошибка${reset}: Контрольная сумма Yq не совпадает\n"
                    else
                        mv "$yq_dist" "$install_dir/yq"
                        chmod +x "$install_dir/yq"
                        if "$install_dir/yq" -V >/dev/null 2>&1; then
                            yq_available="true"
                            printf "  Yq ${green}успешно загружен и установлен${reset}\n"
                        else
                            rm -f "$install_dir/yq"
                            printf "  ${red}Ошибка${reset}: Загруженный Yq не запускается на этой архитектуре (возможно, регрессия upstream — см. ${yellow}$yq_workaround_issue_url${reset})\n"
                        fi
                    fi
                else
                    rm -f "$yq_dist"
                    printf "  ${red}Ошибка${reset}: Загруженный файл Yq поврежден\n"
                fi
            else
                rm -f "$yq_dist"
                printf "  ${red}Ошибка${reset}: Не удалось загрузить Yq\n"
            fi
        else
            printf "  ${yellow}Предупреждение${reset}: Yq недоступен для загрузки, продолжение без него\n"
        fi

        printf "  ${yellow}Выполняется загрузка${reset} выбранной версии Mihomo\n"

        # Загрузка Mihomo
        if [ "$yq_available" != "true" ] && [ -x "$install_dir/yq" ]; then
            rm -f "$yq_dist"
            if "$install_dir/yq" -V >/dev/null 2>&1; then
                yq_available="true"
                printf "  ${yellow}Используется${reset} уже установленный Yq\n"
            else
                printf "  ${red}Ошибка${reset}: Уже установленный Yq не запускается (возможно, несовместим с архитектурой — см. ${yellow}$yq_workaround_issue_url${reset})\n"
            fi
        fi

        if [ "$yq_available" != "true" ]; then
            rm -f "$yq_dist" "$mihomo_dist"
            printf "  ${red}Ошибка${reset}: Для работы Mihomo требуется Yq. Установка прервана\n"
            return 1
        fi

        # Получаем SHA256 дайджест из GitHub API (напрямую, без прокси)
        mihomo_expected_sha256=""
        mihomo_api_digest=$(curl --connect-timeout 10 $curl_timeout -s "https://api.github.com/repos/MetaCubeX/mihomo/releases/tags/$VERSION_ARG" 2>/dev/null \
            | jq -r --arg fname "$(basename "$download_url" | sed "s|.*/||")" '.assets[] | select(.name == $fname) | .digest // empty' 2>/dev/null)
        if [ -n "$mihomo_api_digest" ]; then
            mihomo_expected_sha256=$(printf '%s' "$mihomo_api_digest" | sed 's/^sha256://')
        fi

        if curl --connect-timeout 10 $curl_timeout \
               -fL \
               -o "$mihomo_dist" \
               "$download_url" 2>/dev/null; then

            if [ -s "$mihomo_dist" ]; then
                if head -c 100 "$mihomo_dist" 2>/dev/null | grep -iq "<!DOCTYPE html\|<html\|Error\|404\|Not Found"; then
                    rm -f "$mihomo_dist"
                    printf "  ${red}Ошибка${reset}: Получена HTML страница ошибки вместо файла Mihomo\n"
                    continue
                fi

                # Проверка целостности
                if ! verify_download_integrity "$mihomo_dist" "$mihomo_expected_sha256"; then
                    rm -f "$mihomo_dist"
                    printf "  ${red}Файл удалён${reset}. Попробуйте загрузить другую версию\n"
                    continue
                fi
                
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
