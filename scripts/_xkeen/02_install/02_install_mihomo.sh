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

    if [ -f "$install_dir/mihomo" ]; then
        mv "$install_dir/mihomo" "$install_dir/mihomo_bak"
    fi

    _mihomo_tmp="${mtmp_dir}/mihomo.tmp.$$"
    gzip_err="${mtmp_dir}/gzip.err.$$"
    if gzip -cd "${mihomo_archive}" > "${_mihomo_tmp}" 2>"${gzip_err}" && [ -s "${_mihomo_tmp}" ]; then
        rm -f "${gzip_err}"
    else
        _err="$(cat "${gzip_err}" 2>/dev/null)"
        rm -f "${gzip_err}" "${_mihomo_tmp}" "${mihomo_archive}"
        echo -e "  ${red}Ошибка${reset}: Не удалось распаковать архив Mihomo"
        [ -n "${_err}" ] && echo -e "  Подробности: ${_err}"
        case "${_err}" in
            *"No space left"*|*"ENOSPC"*|*"места"*)
                echo -e "  ${yellow}Недостаточно свободного места${reset} на разделе с ${install_dir}"
                ;;
        esac
        if [ -f "$install_dir/mihomo_bak" ]; then
            mv "$install_dir/mihomo_bak" "$install_dir/mihomo"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Mihomo"
        fi
        return 1
    fi

    # Валидация ELF-сигнатуры распакованного файла (защита от обрезанного gzip-вывода)
    elf_magic="$(dd if="${_mihomo_tmp}" bs=4 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n\t')"
    if [ "${elf_magic}" != "7f454c46" ]; then
        rm -f "${_mihomo_tmp}" "${mihomo_archive}"
        echo -e "  ${red}Ошибка${reset}: Распакованный файл Mihomo не является ELF-бинарём (повреждён или не докачан)"
        if [ -f "$install_dir/mihomo_bak" ]; then
            mv "$install_dir/mihomo_bak" "$install_dir/mihomo"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Mihomo"
        fi
        return 1
    fi

    # Sanity-size: Mihomo binary весит 10+ MB, меньше 1 MB означает обрезанный файл
    sz="$(wc -c < "${_mihomo_tmp}" 2>/dev/null)"
    case "$sz" in
        ''|*[!0-9]*) sz=0 ;;
    esac
    if [ "$sz" -lt 1048576 ]; then
        rm -f "${_mihomo_tmp}" "${mihomo_archive}"
        echo -e "  ${red}Ошибка${reset}: Распакованный файл Mihomo подозрительно мал (${sz} B) — вероятно, обрезан"
        if [ -f "$install_dir/mihomo_bak" ]; then
            mv "$install_dir/mihomo_bak" "$install_dir/mihomo"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Mihomo"
        fi
        return 1
    fi

    mv "${_mihomo_tmp}" "${mtmp_dir}/mihomo"
    rm -f "${mihomo_archive}"

    if [ ! -f "${mtmp_dir}/mihomo" ]; then
        echo -e "  ${red}Ошибка${reset}: Не удалось распаковать архив или файл отсутствует"
        if [ -f "$install_dir/mihomo_bak" ]; then
            mv "$install_dir/mihomo_bak" "$install_dir/mihomo"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Mihomo"
        fi
        return 1
    fi

    mv_err="${mtmp_dir}/mv.err.$$"
    if ! mv "${mtmp_dir}/mihomo" "$install_dir/" 2>"${mv_err}"; then
        _err="$(cat "${mv_err}" 2>/dev/null)"
        rm -f "${mv_err}" "${mtmp_dir}/mihomo"
        echo -e "  ${red}Ошибка${reset}: Не удалось переместить Mihomo в ${install_dir}"
        [ -n "${_err}" ] && echo -e "  Подробности: ${_err}"
        case "${_err}" in
            *"No space left"*|*"ENOSPC"*|*"места"*)
                echo -e "  ${yellow}Недостаточно свободного места${reset} на разделе с ${install_dir}"
                ;;
        esac
        if [ -f "$install_dir/mihomo_bak" ]; then
            mv "$install_dir/mihomo_bak" "$install_dir/mihomo"
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Mihomo"
        fi
        return 1
    fi
    rm -f "${mv_err}"

    chmod +x "$install_dir/mihomo"

    # Финальная проверка: бинарь существует, исполняем, запускается
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
