# Загрузка xkeen
download_xkeen() {
    if [ -n "$xkeen_tar_url" ]; then
        xkeen_dist=$(mktemp)
        mkdir -p "$tmp_dir"
        echo -e "  ${yellow}Выполняется загрузка${reset} XKeen"

        # Загрузка файла с использованием cURL и сохранение его во временной директории
        if curl -L -o "$xkeen_dist" "$xkeen_tar_url" &> /dev/null; then
            if [ -s "$xkeen_dist" ]; then
                mv "$xkeen_dist" "$tmp_dir/xkeen.tar.gz"
                echo -e "  XKeen ${green}успешно загружен${reset}"
            else
                echo -e "  ${red}Ошибка${reset} при загрузке XKeen"
            fi
        fi
    else
        echo -e "  ${red}Ошибка${reset}: Не удалось загрузить XKeen. Проверьте соединение с интернетом или повторите позже"
    fi
    rm -f "$xkeen_dist"
}

download_xkeen_test() {
    if [ -n "$xkeen_test_url" ]; then
        xkeen_dist=$(mktemp)
        mkdir -p "$tmp_dir"

        echo -e "  ${yellow}Выполняется загрузка${reset} XKeen"
        if curl -L -o "$xkeen_dist" "$xkeen_test_url" &> /dev/null; then
            if [ -s "$xkeen_dist" ]; then
                mv "$xkeen_dist" "$tmp_dir/xkeen.tar.gz"
                echo -e "  XKeen ${green}успешно загружен${reset}"
            else
                echo -e "  ${red}Ошибка${reset} при загрузке XKeen"
            fi
        fi
    else
        echo -e "  ${red}Ошибка${reset}: Не удалось загрузить XKeen. Проверьте соединение с интернетом или повторите позже"
    fi
    rm -f "$xkeen_dist"
}