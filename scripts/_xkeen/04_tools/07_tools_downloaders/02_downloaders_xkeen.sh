# Загрузка XKeen
download_xkeen() {
    mkdir -p "$tmp_ram"

    # Инициализация параметров повтора загрузки
    local max_attempts=1
    if [ -n "$retries_download" ] && [ "$retries_download" -gt 1 ] 2>/dev/null; then
        max_attempts=$retries_download
    fi
    local delay=${retry_delay_download:-2}

    local attempt=1
    local success=1

    while [ "$attempt" -le "$max_attempts" ]; do
        if [ "$max_attempts" -gt 1 ]; then
            printf "  Выполняется загрузка XKeen (Попытка %d из %d)...\n" "$attempt" "$max_attempts"
        else
            printf "  ${yellow}Выполняется загрузка${reset} XKeen\n"
        fi

        if fetch_with_mirrors "$xkeen_tar_url" "$tmp_ram/xkeen.tar.gz" 1024; then
            success=0
            break
        fi

        if [ "$attempt" -lt "$max_attempts" ]; then
            printf "  ${yellow}Предупреждение${reset}: Не удалось загрузить XKeen. Повтор через %d сек...\n" "$delay"
            sleep "$delay"
        fi

        attempt=$((attempt + 1))
    done

    if [ "$success" -ne 0 ]; then
        if [ "$max_attempts" -gt 1 ]; then
            printf "  ${red}Ошибка${reset}: Не удалось загрузить XKeen после %d попыток\n" "$max_attempts"
        else
            printf "  ${red}Ошибка${reset}: Не удалось загрузить XKeen\n"
        fi
        exit 1
    fi

    printf "  XKeen ${green}успешно загружен${reset}\n"
    return 0
}

download_xkeen_dev() {
    xkeen_tar_url="$xkeen_dev_url"
    download_xkeen
}