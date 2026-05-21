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

    # Проверка свободного места на разделе с install_dir / xtmp_dir
    free_kb="$(df -P -k "$install_dir" 2>/dev/null | awk 'NR==2 {print $4}')"
    case "$free_kb" in
        ''|*[!0-9]*) free_kb=0 ;;
    esac
    required_kb=81920    # 80 MB
    if [ "$free_kb" -lt "$required_kb" ]; then
        free_mb=$(( free_kb / 1024 ))
        echo -e "  ${red}Ошибка${reset}: Недостаточно свободного места на разделе ${yellow}${install_dir}${reset}"
        echo -e "  Свободно: ${yellow}${free_mb} MB${reset}, требуется: ${yellow}80 MB${reset}"
        echo -e "  Освободите место или переустановите XKeen на внешний накопитель"
        rm -f "${xray_archive}"
        return 1
    fi

    if [ -f "$install_dir/xray" ]; then
        mv "$install_dir/xray" "$install_dir/xray_bak"
    fi

    # Распаковка архива Xray
    if [ -d "${xtmp_dir}/xray" ]; then
        rm -rf "${xtmp_dir}/xray"
    fi

    unzip_err="${xtmp_dir}/unzip.err.$$"
    if ! unzip -q "${xray_archive}" -d "${xtmp_dir}/xray" 2>"${unzip_err}"; then
        _err="$(cat "${unzip_err}" 2>/dev/null)"
        rm -f "${unzip_err}"
        rm -rf "${xtmp_dir}/xray"
        rm -f "${xray_archive}"
        echo -e "  ${red}Ошибка${reset}: Не удалось распаковать архив Xray"
        [ -n "${_err}" ] && echo -e "  Подробности: ${_err}"
        if [ -f "$install_dir/xray_bak" ]; then
            mv "$install_dir/xray_bak" "$install_dir/xray"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Xray"
        fi
        return 1
    fi
    rm -f "${unzip_err}"

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

    if ! mv "$bin_source" "$install_dir/xray" 2>/dev/null; then
        echo -e "  ${red}Ошибка${reset}: Не удалось переместить Xray в ${install_dir} (нет места или прав?)"
        rm -f "$xray_archive"
        rm -rf "${xtmp_dir}/xray"
        if [ -f "$install_dir/xray_bak" ]; then
            mv "$install_dir/xray_bak" "$install_dir/xray"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Xray"
        fi
        return 1
    fi
    chmod +x "$install_dir/xray"

    # Пост-проверка: бинарь существует, имеет +x, запускается
    if [ ! -x "$install_dir/xray" ] || ! "$install_dir/xray" version >/dev/null 2>&1; then
        echo -e "  ${red}Ошибка${reset}: Установленный Xray не запускается (повреждён или несовместим с архитектурой)"
        rm -f "$install_dir/xray"
        rm -f "$xray_archive"
        rm -rf "${xtmp_dir}/xray"
        if [ -f "$install_dir/xray_bak" ]; then
            mv "$install_dir/xray_bak" "$install_dir/xray"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Xray"
        fi
        return 1
    fi

    rm -f "$install_dir/xray_bak"
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
