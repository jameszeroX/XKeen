# Загрузка XKeen
download_xkeen() {
    mkdir -p "$ktmp_dir"
    printf "  ${yellow}Выполняется загрузка${reset} XKeen\n"

    if ! fetch_with_mirrors "$xkeen_tar_url" "$ktmp_dir/xkeen.tar.gz" 1024; then
        printf "  ${red}Ошибка${reset}: Не удалось загрузить XKeen\n"
        exit 1
    fi

    printf "  XKeen ${green}успешно загружен${reset}\n"
    return 0
}

download_xkeen_dev() {
    xkeen_tar_url="$xkeen_dev_url"
    download_xkeen
}