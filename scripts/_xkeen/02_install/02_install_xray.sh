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
        case "${_err}" in
            *"No space left"*|*"ENOSPC"*|*"места"*)
                echo -e "  ${yellow}Недостаточно свободного места${reset} на разделе с ${install_dir}"
                ;;
        esac
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

    # Валидация ELF-сигнатуры (защита от обрезанного unzip-вывода)
    elf_magic="$(hexdump -n 4 -e '4/1 "%02x"' "$bin_source" 2>/dev/null)"
    if [ "${elf_magic}" != "7f454c46" ]; then
        echo -e "  ${red}Ошибка${reset}: Распакованный файл Xray не является ELF-бинарником (повреждён или не докачан)"
        if [ -f "$install_dir/xray_bak" ]; then
            mv "$install_dir/xray_bak" "$install_dir/xray"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Xray"
        fi
        rm -f "$xray_archive"
        rm -rf "${xtmp_dir}/xray"
        return 1
    fi

    # Sanity-size: Xray binary весит 15+ MB, меньше 1 MB означает обрезанный файл
    sz="$(wc -c < "$bin_source" 2>/dev/null)"
    case "$sz" in
        ''|*[!0-9]*) sz=0 ;;
    esac
    if [ "$sz" -lt 1048576 ]; then
        echo -e "  ${red}Ошибка${reset}: Распакованный файл Xray подозрительно мал (${sz} B) — вероятно, обрезан"
        if [ -f "$install_dir/xray_bak" ]; then
            mv "$install_dir/xray_bak" "$install_dir/xray"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Xray"
        fi
        rm -f "$xray_archive"
        rm -rf "${xtmp_dir}/xray"
        return 1
    fi

    mv_err="${xtmp_dir}/mv.err.$$"
    if ! mv "$bin_source" "$install_dir/xray" 2>"${mv_err}"; then
        _err="$(cat "${mv_err}" 2>/dev/null)"
        rm -f "${mv_err}"
        echo -e "  ${red}Ошибка${reset}: Не удалось переместить Xray в ${install_dir}"
        [ -n "${_err}" ] && echo -e "  Подробности: ${_err}"
        case "${_err}" in
            *"No space left"*|*"ENOSPC"*|*"места"*)
                echo -e "  ${yellow}Недостаточно свободного места${reset} на разделе с ${install_dir}"
                ;;
        esac
        if [ -f "$install_dir/xray_bak" ]; then
            mv "$install_dir/xray_bak" "$install_dir/xray"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Xray"
        fi
        rm -f "$xray_archive"
        rm -rf "${xtmp_dir}/xray"
        return 1
    fi
    rm -f "${mv_err}"

    chmod +x "$install_dir/xray"

    # Финальная проверка: бинарник существует, исполняем, запускается
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
