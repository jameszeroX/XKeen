# Функция для получения версии из xkeen API и сохранения ее в переменной
info_version_xkeen() {
    local max_attempts=1
    if [ -n "$retries_download" ] && [ "$retries_download" -gt 1 ] 2>/dev/null; then
        max_attempts=$retries_download
    fi
    local delay=${retry_delay_download:-2}

    local attempt=1
    local version=""

    while [ "$attempt" -le "$max_attempts" ]; do
        version=$(curl_with_timeout -s "$xkeen_api_url" | jq -r '.tag_name // .name // ""' 2>/dev/null)

        if [ -z "$version" ]; then
            if [ "$attempt" -eq 1 ]; then
                echo
                printf "${red}Нет доступа${reset} к ${yellow}GitHub API${reset}, пробуем ${yellow}jsDelivr${reset}...\n"
            fi
            version=$(curl_with_timeout -s "$xkeen_jsd_url" | jq -r '.versions | first' 2>/dev/null)
        fi

        if [ -n "$version" ]; then
            break
        fi

        if [ "$attempt" -lt "$max_attempts" ]; then
            printf "  ${yellow}Повтор через %d сек${reset} (попытка %d из %d)...\n" "$delay" "$((attempt + 1))" "$max_attempts"
            sleep "$delay"
        fi

        attempt=$((attempt + 1))
    done

    if [ -z "$version" ]; then
        echo
        printf "  ${red}Нет доступа${reset} к ${yellow}jsDelivr${reset}\n"
        echo
        printf "${red}Ошибка${reset}: Не удалось получить версию ни с ${yellow}GitHub${reset}, ни с ${yellow}jsDelivr${reset}\n
  Проверьте соединение с интернетом или повторите позже\n
  Если ошибка сохраняется, воспользуйтесь возможностью OffLine установки:\n
  https://github.com/jameszeroX/XKeen/blob/main/OffLine_install.md\n"
        echo
        exit 1
    fi

    xkeen_github_version="${version}"
}

# Функция для сравнения версий XKeen
info_compare_xkeen() {
    if [ "$xkeen_current_version" = "$xkeen_github_version" ]; then
        info_compare_xkeen="actual"
    else
        info_compare_xkeen="update"
    fi
}