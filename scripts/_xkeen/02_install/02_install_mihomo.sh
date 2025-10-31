# Функция для установки Mihomo
install_mihomo() {
    echo -e "  ${yellow}Выполняется установка${reset} Mihomo. Пожалуйста, подождите..."

    # Определение переменных
    mihomo_archive="${mtmp_dir}/mihomo.gz"

    # Проверка наличия архива Mihomo
    if [ -f "${mihomo_archive}" ]; then

        if [ -f "$install_dir/mihomo" ]; then
            mv "$install_dir/mihomo" "$install_dir/mihomo_bak"
        fi

        # Распаковка архива Mihomo
        if [ -d "${mtmp_dir}/mihomo" ]; then
            rm -r "${mtmp_dir}/mihomo"
        fi

        if gzip -d "${mihomo_archive}"; then
            mv "${mtmp_dir}/mihomo" $install_dir/
            chmod +x $install_dir/mihomo
            echo -e "  Mihomo ${green}успешно установлен${reset}"
        fi

        # Удаление временных файлов
        rm -rf "${mtmp_dir}/mihomo"
    fi
}