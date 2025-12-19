# Загрузка XKeen
download_xkeen() {
    xkeen_dist=$(mktemp)
    mkdir -p "$tmp_dir"
    printf "  ${yellow}Выполняется загрузка${reset} XKeen\n"

    if [ "$use_direct" != "true" ]; then
        xkeen_tar_url="$gh_proxy/$xkeen_tar_url"
    fi

    if curl --connect-timeout 10 -m 60 -fL -o "$xkeen_dist" "$xkeen_tar_url" 2>/dev/null; then
        if [ -s "$xkeen_dist" ]; then
            mv "$xkeen_dist" "$tmp_dir/xkeen.tar.gz"
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