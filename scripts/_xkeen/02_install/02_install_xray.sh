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

    if ! unzip -q "${xray_archive}" -d "${xtmp_dir}/xray"; then
        echo -e "  ${red}Ошибка${reset}: Не удалось распаковать архив"
        [ -f "$install_dir/xray_bak" ] && mv "$install_dir/xray_bak" "$install_dir/xray"
        return 1
    fi

    bin_source="${xtmp_dir}/xray/xray"

    if [ "$softfloat" = "true" ]; then
        if [ -f "${xtmp_dir}/xray/xray_softfloat" ]; then
            bin_source="${xtmp_dir}/xray/xray_softfloat"
        fi
    fi

    if [ ! -f "$bin_source" ]; then
        echo -e "  ${red}Ошибка${reset}: Бинарный файл Xray не найден в архиве"
        if [ -f "$install_dir/xray_bak" ]; then
            mv "$install_dir/xray_bak" "$install_dir/xray"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Xray"
        fi
        rm -f "$xray_archive"
        rm -rf "${xtmp_dir}/xray"
        return 1
    fi

    mv "$bin_source" "$install_dir/xray"
    chmod +x "$install_dir/xray"
    echo -e "  Xray ${green}успешно установлен${reset}"

    rm -f "$xray_archive"
    rm -rf "${xtmp_dir}/xray"

    # Фикс для новых ядер xray
    if [ -d "$xray_conf_dir" ]; then
        for file in "$xray_conf_dir"/*.json; do
            [ -f "$file" ] || continue
            if grep -qE '"transport"\s*:' "$file"; then
                mv "$file" "${file}.obsolete"
            fi
        done
    fi

    return 0
}