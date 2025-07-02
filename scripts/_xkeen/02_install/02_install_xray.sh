# Функция для установки Xray
install_xray() {
    echo -e "  ${yellow}Выполняется установка${reset} Xray. Пожалуйста, подождите..."

    # Определение переменных
    xray_archive="${xtmp_dir}/xray.zip"

    # Проверка наличия архива Xray
    if [ -f "${xray_archive}" ]; then

        if [ -f "$install_dir/xray" ]; then
            mv "$install_dir/xray" "$install_dir/xray_bak"
        fi

        # Распаковка архива Xray
        if [ -d "${xtmp_dir}/xray" ]; then
            rm -r "${xtmp_dir}/xray"
        fi

        if unzip -q "${xray_archive}" -d "${xtmp_dir}/xray"; then
            mv "${xtmp_dir}/xray/xray" $install_dir/
            chmod +x $install_dir/xray
        fi

        # Удаление архива Xray
        rm "${xray_archive}"

        # Удаление временных файлов
        rm -rf "${xtmp_dir}/xray"

        # Фикс для новых ядер xray
        if [ -f "$install_conf_dir"/*transport* ]; then
            rm -f "$install_conf_dir"/*transport*
        fi
    fi
}