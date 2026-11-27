# Функция для установки файлов конфигурации Xray
xray_conf_install() {
    if [ ! -d "$xray_conf_dir" ]; then
        mkdir -p "$xray_conf_dir" || {
            echo -e "  ${red}Ошибка${reset}: Не удалось создать директорию конфигурации Xray $xray_conf_dir" >&2
            return 1
        }
    fi

    if ls "$xray_conf_dir"/*.json >/dev/null 2>&1; then
        return 0
    fi

    for file in "$xray_conf_smpl"/*.json; do
        # Если шаблонов нет, цикл получает буквальный шаблон "*.json"
        if [ ! -f "$file" ]; then
            echo -e "  ${red}Ошибка${reset}: Шаблоны конфигурации Xray не найдены в $xray_conf_smpl" >&2
            return 1
        fi
        filename=$(basename "$file")
        if ! cp "$file" "$xray_conf_dir/"; then
            echo -e "  ${red}Ошибка${reset}: Не удалось скопировать шаблон конфигурации Xray $filename" >&2
            return 1
        fi
        echo "  Добавлен шаблон конфигурационного файла Xray:"
        echo -e "  ${yellow}$filename${reset}"
        sleep 1
    done
}

# Проверка конфигурации ядра проксирования
core_conf_test() {
    local core="$1"
    local path="$install_dir/$core"
    local core_title
    set_core_title "$core"

    if [ ! -f "$path" ] || [ ! -x "$path" ]; then
        echo -e "  ${red}Ошибка${reset}: Не найден или повреждён исполняемый файл ядра проксирования ${green}$core_title${reset}"
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
