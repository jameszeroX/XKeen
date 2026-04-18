# Функция для установки Xray
install_xray() {
    echo -e "  ${yellow}Выполняется установка${reset} Xray. Пожалуйста, подождите..."

    # Определение переменных
    xray_archive="${xtmp_dir}/xray.zip"

    # Проверка наличия архива Xray
    if [ ! -f "${xray_archive}" ]; then
        echo -e "  ${red}Ошибка${reset}: Архив Xray не найден в '${xtmp_dir}'"
        return 1
    fi

    if [ -f "$install_dir/xray" ]; then
        mv "$install_dir/xray" "$install_dir/xray_bak"
    fi

    # Распаковка архива Xray
    if [ -d "${xtmp_dir}/xray" ]; then
        rm -rf "${xtmp_dir}/xray"
    fi

    if ! unzip -q "${xray_archive}" -d "${xtmp_dir}/xray" || [ ! -f "${xtmp_dir}/xray/xray" ]; then
        echo -e "  ${red}Ошибка${reset}: Не удалось распаковать архив или отсутствует бинарный файл"
        if [ -f "$install_dir/xray_bak" ]; then
            mv "$install_dir/xray_bak" "$install_dir/xray"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Xray"
        fi
        rm -f "$xray_archive"
        rm -rf "${xtmp_dir}/xray"
        return 1
    fi

    mv "${xtmp_dir}/xray/xray" "$install_dir/"
    chmod +x "$install_dir/xray"
    echo -e "  Xray ${green}успешно установлен${reset}"

    # Удаление архива Xray
    rm -f "$xray_archive"

    # Удаление временных файлов
    rm -rf "${xtmp_dir}/xray"

    # Фикс для новых ядер xray
    if [ -d "$install_conf_dir" ]; then
        for file in "$install_conf_dir"/*.json; do
            [ -f "$file" ] || continue
            if grep -qE '"transport"\s*:' "$file"; then
                mv "$file" "${file}.bad"
            fi
        done
    fi

    return 0
}