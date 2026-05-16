# Функция для установки Mihomo
install_mihomo() {
    echo -e "  ${yellow}Выполняется установка${reset} Mihomo. Пожалуйста, подождите..."

    # Определение переменных
    mihomo_archive="${mtmp_dir}/mihomo.gz"

    # Проверка наличия архива Mihomo
    if [ ! -f "${mihomo_archive}" ]; then
        echo -e "  ${red}Ошибка${reset}: Архив Mihomo не найден в '${mtmp_dir}'"
        return 1
    fi

    if [ -f "$install_dir/mihomo" ]; then
        mv "$install_dir/mihomo" "$install_dir/mihomo_bak"
    fi

    _mihomo_tmp="${mtmp_dir}/mihomo.tmp.$$"
    if gzip -cd "${mihomo_archive}" > "${_mihomo_tmp}" 2>/dev/null && [ -s "${_mihomo_tmp}" ]; then
        mv "${_mihomo_tmp}" "${mtmp_dir}/mihomo"
        rm -f "${mihomo_archive}"
    else
        rm -f "${_mihomo_tmp}" "${mihomo_archive}"
        echo -e "  ${red}Ошибка${reset}: Не удалось распаковать архив или файл отсутствует"
        if [ -f "$install_dir/mihomo_bak" ]; then
            mv "$install_dir/mihomo_bak" "$install_dir/mihomo"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Mihomo"
        fi
        return 1
    fi
    if [ ! -f "${mtmp_dir}/mihomo" ]; then
        echo -e "  ${red}Ошибка${reset}: Не удалось распаковать архив или файл отсутствует"
        if [ -f "$install_dir/mihomo_bak" ]; then
            mv "$install_dir/mihomo_bak" "$install_dir/mihomo"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Mihomo"
        fi
        return 1
    fi

    if ! mv "${mtmp_dir}/mihomo" "$install_dir/"; then
        echo -e "  ${red}Ошибка${reset}: Не удалось установить Mihomo"
        [ -f "$install_dir/mihomo_bak" ] && mv "$install_dir/mihomo_bak" "$install_dir/mihomo"
        return 1
    fi

    chmod +x "$install_dir/mihomo"
    echo -e "  Mihomo ${green}успешно установлен${reset}"

    return 0
}