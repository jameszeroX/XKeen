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

    # Проверка свободного места на разделе с install_dir / mtmp_dir
    # Требуется запас на распакованный бинарь и tmp-копию одновременно
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
        rm -f "${mihomo_archive}"
        return 1
    fi

    if [ -f "$install_dir/mihomo" ]; then
        mv "$install_dir/mihomo" "$install_dir/mihomo_bak"
    fi

    _mihomo_tmp="${mtmp_dir}/mihomo.tmp.$$"
    gzip_err="${mtmp_dir}/gzip.err.$$"
    if gzip -cd "${mihomo_archive}" > "${_mihomo_tmp}" 2>"${gzip_err}" && [ -s "${_mihomo_tmp}" ]; then
        rm -f "${gzip_err}"
        mv "${_mihomo_tmp}" "${mtmp_dir}/mihomo"
        rm -f "${mihomo_archive}"
    else
        _err="$(cat "${gzip_err}" 2>/dev/null)"
        rm -f "${gzip_err}" "${_mihomo_tmp}" "${mihomo_archive}"
        echo -e "  ${red}Ошибка${reset}: Не удалось распаковать архив Mihomo"
        [ -n "${_err}" ] && echo -e "  Подробности: ${_err}"
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

    if ! mv "${mtmp_dir}/mihomo" "$install_dir/" 2>/dev/null; then
        echo -e "  ${red}Ошибка${reset}: Не удалось переместить Mihomo в ${install_dir} (нет места или прав?)"
        rm -f "${mtmp_dir}/mihomo"
        if [ -f "$install_dir/mihomo_bak" ]; then
            mv "$install_dir/mihomo_bak" "$install_dir/mihomo"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Mihomo"
        fi
        return 1
    fi

    chmod +x "$install_dir/mihomo"

    # Пост-проверка: бинарь существует, имеет +x, запускается
    if [ ! -x "$install_dir/mihomo" ] || ! "$install_dir/mihomo" -v >/dev/null 2>&1; then
        echo -e "  ${red}Ошибка${reset}: Установленный Mihomo не запускается (повреждён или несовместим с архитектурой)"
        rm -f "$install_dir/mihomo"
        if [ -f "$install_dir/mihomo_bak" ]; then
            mv "$install_dir/mihomo_bak" "$install_dir/mihomo"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Mihomo"
        fi
        return 1
    fi

    rm -f "$install_dir/mihomo_bak"
    echo -e "  Mihomo ${green}успешно установлен${reset}"

    return 0
}
