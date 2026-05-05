# Функция для установки файлов конфигурации Xray
install_configs() {
    if [ ! -d "$xray_conf_dir" ]; then
        mkdir -p "$xray_conf_dir"
    fi

    if ls "$xray_conf_dir"/*.json >/dev/null 2>&1; then
        return 0
    fi

    xray_files="$xray_conf_smpl"/*.json
    for file in $xray_files; do
        filename=$(basename "$file")
        cp "$file" "$xray_conf_dir/"
        echo "  Добавлен шаблон конфигурационного файла Xray:"
        echo -e "  ${yellow}$filename${reset}"
        sleep 1
    done
}
