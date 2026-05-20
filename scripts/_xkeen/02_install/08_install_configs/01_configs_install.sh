# Функция для установки файлов конфигурации Xray
xray_conf_install() {
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

# Проверка конфигурации прокси-клиента
core_conf_test() {
    local core="$1"
    local path="$install_dir/$core"

    if [ ! -f "$path" ] || [ ! -x "$path" ]; then
        echo -e "  ${red}Ошибка${reset}: Не найден или повреждён исполняемый файл прокси-клиента ${green}$core${reset}"
        return 1
    fi

    case "$core" in
        "xray")
            export XRAY_LOCATION_CONFDIR="$xray_conf_dir"
            export XRAY_LOCATION_ASSET="$geo_dir"
            "$path" -format=json -test
            ;;
        "mihomo")
            export CLASH_HOME_DIR="$mihomo_conf_dir"
            "$path" -t
            ;;
    esac
}