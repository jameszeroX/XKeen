# Функция для установки файлов конфигурации xray
install_configs() {
    if [ ! -d "$install_conf_dir" ]; then
        mkdir -p "$install_conf_dir"
    fi

    if ls "$install_conf_dir"/*.json >/dev/null 2>&1; then
        return 0
    fi

    xkeen_files="$xkeen_conf_dir"/*.json
    for file in $xkeen_files; do
        filename=$(basename "$file")
        cp "$file" "$install_conf_dir/"
        echo -e "  Добавлен шаблон кофигурационного файла xray:"
        echo -e "  ${yellow}$filename${reset}"
        sleep 2
    done
}
