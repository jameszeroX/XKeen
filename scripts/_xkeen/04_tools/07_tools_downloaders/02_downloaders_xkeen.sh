# Загрузка XKeen
verify_xkeen_signature() {
    archive="$1"
    signature="${archive}.minisig"
    public_key="$xkeen_dir/keys/xkeen.minisign.pub"

    [ "$verify_downloads" = "off" ] && return 0
    if ! fetch_with_mirrors "${xkeen_tar_url}.minisig" "$signature" 32; then
        if [ "$verify_downloads" = "strict" ]; then
            printf "  ${red}Ошибка${reset}: подпись XKeen недоступна в strict-режиме\n"
            return 1
        fi
        printf "  ${yellow}Предупреждение${reset}: подпись XKeen отсутствует (старый или неподписанный релиз)\n"
        return 0
    fi
    if [ ! -r "$public_key" ] || ! command -v minisign >/dev/null 2>&1; then
        printf "  ${red}Ошибка${reset}: релиз подписан, но отсутствует ключ или minisign\n"
        return 1
    fi
    minisign -Vm "$archive" -x "$signature" -P "$(cat "$public_key")" >/dev/null 2>&1 || {
        printf "  ${red}Ошибка${reset}: подпись XKeen не прошла проверку\n"
        return 1
    }
    printf "  Подпись XKeen ${green}проверена${reset}\n"
}

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
            if verify_xkeen_signature "$tmp_ram/xkeen.tar.gz"; then
                success=0
                break
            fi
            rm -f "$tmp_ram/xkeen.tar.gz" "$tmp_ram/xkeen.tar.gz.minisig"
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