# Загрузка XKeen
download_xkeen() {
    test_github
    xkeen_dist=$(mktemp)
    mkdir -p "$ktmp_dir"
    printf "  ${yellow}Выполняется загрузка${reset} XKeen\n"

    sha256_url="${xkeen_tar_url}.sha256"

    if [ "$use_direct" != "true" ]; then
        xkeen_tar_url="$gh_proxy/$xkeen_tar_url"
    fi

    if curl --connect-timeout 10 $curl_timeout -fL -o "$xkeen_dist" "$xkeen_tar_url" 2>/dev/null; then
        if [ -s "$xkeen_dist" ]; then
            expected_sha256=""
            sha256_content=$(curl --connect-timeout 10 $curl_timeout -sfL "$sha256_url" 2>/dev/null)
            if [ -n "$sha256_content" ]; then
                expected_sha256=$(printf '%s\n' "$sha256_content" | awk '{print $1}')
            fi
            
            if ! verify_download_integrity "$xkeen_dist" "$expected_sha256"; then
                rm -f "$xkeen_dist"
                printf "  ${red}Ошибка${reset}: Контрольная сумма не совпадает\n"
                exit 1
            fi
            
            mv "$xkeen_dist" "$ktmp_dir/xkeen.tar.gz"
            printf "  XKeen ${green}успешно загружен${reset}\n"
            return 0
        else
            rm -f "$xkeen_dist"
            printf "  ${red}Ошибка${reset}: Загруженный файл XKeen поврежден\n"
            exit 1
        fi
    else
        rm -f "$xkeen_dist"
        printf "  ${red}Ошибка${reset}: Не удалось загрузить XKeen\n"
        exit 1
    fi
}

download_xkeen_dev() {
    xkeen_tar_url="$xkeen_dev_url"
    download_xkeen
}