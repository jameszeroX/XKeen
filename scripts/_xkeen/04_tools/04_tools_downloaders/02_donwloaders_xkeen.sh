# Загрузка XKeen
download_xkeen() {
    xkeen_dist=$(mktemp)
    mkdir -p "$tmp_dir"
    echo -e "  ${yellow}Выполняется загрузка${reset} XKeen"

    # Первая попытка: прямая загрузка
    if curl -L -o "$xkeen_dist" "$xkeen_tar_url" &> /dev/null; then
        if [ -s "$xkeen_dist" ]; then
            mv "$xkeen_dist" "$tmp_dir/xkeen.tar.gz"
            echo -e "  XKeen ${green}успешно загружен${reset}"
            return 0
        else
            echo -e "  ${red}Ошибка${reset}: Загруженный файл XKeen поврежден"
        fi
    else
        # Вторая попытка: загрузка через прокси
        if curl -L -o "$xkeen_dist" "$gh_proxy/$xkeen_tar_url" &> /dev/null; then
            if [ -s "$xkeen_dist" ]; then
                mv "$xkeen_dist" "$tmp_dir/xkeen.tar.gz"
                echo -e "  XKeen ${green}успешно загружен через прокси${reset}"
                return 0
            else
                echo -e "  ${red}Ошибка${reset}: Загруженный файл XKeen поврежден"
            fi
        else
            echo -e "  ${red}Ошибка${reset}: Не удалось загрузить XKeen. Проверьте соединение с интернетом или повторите позже"
        fi
    fi
    rm -f "$xkeen_dist"
    exit 1
}

download_xkeen_dev() {
    xkeen_tar_url="$xkeen_dev_url"
    download_xkeen
}