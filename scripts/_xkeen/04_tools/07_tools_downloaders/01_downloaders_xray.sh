# Сформировать download_url и extension для указанной версии Xray.
# $1 = version_selected (например v25.4.30)
# Устанавливает глобальные переменные: download_url, filename, extension
# Возврат: 0 — успех, 1 — неизвестная архитектура
_xray_build_url() {
    _xbu_version="$1"
    _xbu_base="${xray_zip_url}/$_xbu_version"
    case "$architecture" in
        "arm64-v8a") download_url="$_xbu_base/Xray-linux-arm64-v8a.zip" ;;
        "mips32le")  download_url="$_xbu_base/Xray-linux-mips32le.zip" ;;
        "mips32")    download_url="$_xbu_base/Xray-linux-mips32.zip" ;;
        *)           download_url=; return 1 ;;
    esac
    filename=$(basename "$download_url")
    extension="${filename##*.}"
    return 0
}

# Функция для проверки и загрузки выбранной версии Xray
# $1 = version_selected
_xray_perform_install() {
    local version="$1"
    if ! _xray_build_url "$version"; then
        printf "  ${red}Ошибка${reset}: Не удалось получить URL для загрузки Xray\n"
        return 1
    fi
    mkdir -p "$tmp_ram"

    if ! _network_probe "$download_url" "версии $version"; then
        return 1
    fi

    printf "  ${yellow}Выполняется загрузка${reset} Xray %s\n" "$version"
    if ! _network_download "$download_url" "$tmp_ram/xray.$extension" "Xray" "$max_attempts" "$delay"; then
        return 1
    fi

    printf "  Xray ${green}успешно загружен${reset}\n"
    return 0
}

# Загрузка Xray
download_xray() {
    USE_JSDELIVR=""
    printf "\n  ${green}Запрос информации${reset} о релизах ${yellow}Xray${reset}\n"
    fetch_release_tags "$xray_api_url" "$xray_jsd_url" "10"

    # --- АВТОМАТИЧЕСКИЙ РЕЖИМ ---
    if [ "$autoinstall_mode" = "true" ]; then
        version_selected=$(echo "$RELEASE_TAGS" | head -1)
        [ "$USE_JSDELIVR" = "true" ] && version_selected="v$version_selected"
        printf "  ${green}Авто-режим${reset}: выбрана последняя версия ${yellow}%s${reset}\n" "$version_selected"

        if _xray_perform_install "$version_selected"; then
            return 0
        else
            exit 1
        fi
    fi

    # --- ИНТЕРАКТИВНЫЙ РЕЖИМ ---
    while true; do
        echo
        echo "$RELEASE_TAGS" | awk '{printf "    %2d. %s\n", NR, $0}'
        echo
        echo "     9. Ручной ввод версии"
        echo
        echo "     0. Пропустить загрузку Xray"

        printf "\n  Введите порядковый номер релиза (0 - пропустить, 9 - ручной ввод): "
        read -r choice

        case "$choice" in
            [0-9]) ;;
            *) 
                printf "  ${red}Некорректный${reset} ввод. Пожалуйста, введите число\n"
                sleep 1
                continue
                ;;
        esac

        if [ "$choice" = "0" ]; then
            bypass_xray="true"
            printf "  Загрузка Xray ${yellow}пропущена${reset}\n"
            return
        fi

        if [ "$choice" = "9" ]; then
            printf "  Введите версию Xray для загрузки (например: v26.6.1): "
            read -r version_selected
            if [ -z "$version_selected" ]; then
                printf "  ${red}Ошибка${reset}: Версия не может быть пустой\n"
                sleep 1
                continue
            fi
            version_selected=$(echo "$version_selected" | sed 's/^v//')
            version_selected="v$version_selected"
        else
            version_selected=$(echo "$RELEASE_TAGS" | awk -v line="$choice" 'NR == line {print $0; exit}')
            if [ -z "$version_selected" ]; then
                printf "  Выбранный номер ${red}вне диапазона.${reset} Пожалуйста, попробуйте снова\n"
                sleep 1
                continue
            fi
            [ "$USE_JSDELIVR" = "true" ] && version_selected="v$version_selected"
        fi

        if _xray_perform_install "$version_selected"; then
            return 0
        fi
    done
}