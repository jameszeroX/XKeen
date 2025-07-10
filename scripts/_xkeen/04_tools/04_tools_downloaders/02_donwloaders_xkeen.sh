# Загрузка XKeen
download_xkeen() {
    xkeen_dist=$(mktemp)
    mkdir -p "$tmp_dir"
    echo -e "  ${yellow}Выполняется загрузка${reset} XKeen"

    if curl -L -o "$xkeen_dist" "$xkeen_tar_url" &> /dev/null; then
        if [ -s "$xkeen_dist" ]; then
            mv "$xkeen_dist" "$tmp_dir/xkeen.tar.gz"
            echo -e "  XKeen ${green}успешно загружен${reset}"
        else
            echo -e "  ${red}Ошибка${reset} при загрузке XKeen"
        fi
    fi
    rm -f "$xkeen_dist"
}

download_xkeen_dev() {
    xkeen_tar_url="$xkeen_dev_url"
    download_xkeen
}