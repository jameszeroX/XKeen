# Функция для установки Xray
install_xray() {
    echo -e "  ${yellow}Выполняется установка${reset} Xray. Пожалуйста, подождите..."

    # Определение переменных
    xray_archive="$tmp_ram/xray.zip"

    # Проверка наличия архива Xray
    if [ ! -f "$xray_archive" ]; then
        echo -e "  ${red}Ошибка${reset}: Архив Xray не найден в '$tmp_ram'"
        return 1
    fi

    if [ -f "$install_dir/xray" ]; then
        mv "$install_dir/xray" "$install_dir/xray_bak"
    fi

    [ -d "$xtmp_dir" ] && rm -rf "$xtmp_dir"
    mkdir -p "$xtmp_dir"

    unzip_err="$xtmp_dir/unzip.err.$$"
    if ! unzip -q "$xray_archive" -d "$xtmp_dir" 2>"$unzip_err"; then
        _err="$(cat "$unzip_err" 2>/dev/null)"
        rm -f "$unzip_err"
        rm -rf "$xtmp_dir"
        rm -f "$xray_archive"
        # Гарантированно убираем возможный маркер незавершенного файла перед восстановлением бэкапа
        rm -f "$install_dir/xray"
        echo -e "  ${red}Ошибка${reset}: Не удалось распаковать архив Xray"
        [ -n "$_err" ] && echo -e "  Подробности: $_err"
        case "$_err" in
            *"No space left"*|*"ENOSPC"*|*"места"*)
                echo -e "  ${yellow}Недостаточно свободного места${reset} на разделе с $install_dir"
                ;;
        esac
        [ -f "$install_dir/xray_bak" ] && mv "$install_dir/xray_bak" "$install_dir/xray" && \
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Xray"
        return 1
    fi
    rm -f "$unzip_err"

    bin_source="$xtmp_dir/xray"
    [ "$softfloat" = "true" ] && [ -f "$xtmp_dir/xray_softfloat" ] && bin_source="$xtmp_dir/xray_softfloat"

    if [ ! -f "$bin_source" ]; then
        echo -e "  ${red}Ошибка${reset}: Бинарный файл Xray не найден в архиве"
        rm -f "$install_dir/xray"
        [ -f "$install_dir/xray_bak" ] && mv "$install_dir/xray_bak" "$install_dir/xray" && \
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Xray"
        rm -f "$xray_archive"
        rm -rf "$xtmp_dir"
        return 1
    fi

    # Валидация ELF-сигнатуры (защита от обрезанного unzip-вывода)
    elf_magic="$(hexdump -n 4 -e '4/1 "%02x"' "$bin_source" 2>/dev/null)"
    if [ "$elf_magic" != "7f454c46" ]; then
        echo -e "  ${red}Ошибка${reset}: Распакованный файл Xray не является ELF-бинарником (повреждён или не докачан)"
        rm -f "$install_dir/xray"
        [ -f "$install_dir/xray_bak" ] && mv "$install_dir/xray_bak" "$install_dir/xray" && \
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Xray"
        rm -f "$xray_archive"
        rm -rf "$xtmp_dir"
        return 1
    fi

    # Sanity-size: Xray binary весит 15+ MB, меньше 1 MB означает обрезанный файл
    sz="$(wc -c < "$bin_source" 2>/dev/null)"
    case "$sz" in ''|*[!0-9]*) sz=0 ;; esac
    if [ "$sz" -lt 1048576 ]; then
        echo -e "  ${red}Ошибка${reset}: Распакованный файл Xray подозрительно мал (${sz} B) — вероятно, обрезан"
        rm -f "$install_dir/xray"
        [ -f "$install_dir/xray_bak" ] && mv "$install_dir/xray_bak" "$install_dir/xray" && \
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Xray"
        rm -f "$xray_archive"
        rm -rf "$xtmp_dir"
        return 1
    fi

    mv_err="$xtmp_dir/mv.err.$$"
    if ! mv "$bin_source" "$install_dir/xray" 2>"$mv_err"; then
        _err="$(cat "$mv_err" 2>/dev/null)"
        rm -f "$mv_err"
        rm -f "$install_dir/xray"
        echo -e "  ${red}Ошибка${reset}: Не удалось переместить Xray в $install_dir"
        [ -n "$_err" ] && echo -e "  Подробности: $_err"
        case "$_err" in
            *"No space left"*|*"ENOSPC"*|*"места"*)
                echo -e "  ${yellow}Недостаточно свободного места${reset} на разделе с $install_dir"
                ;;
        esac
        [ -f "$install_dir/xray_bak" ] && mv "$install_dir/xray_bak" "$install_dir/xray" && \
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Xray"
        rm -f "$xray_archive"
        rm -rf "$xtmp_dir"
        return 1
    fi
    rm -f "$mv_err"

    chmod +x "$install_dir/xray"

    # Финальная проверка: бинарник существует, исполняем, запускается
    if [ ! -x "$install_dir/xray" ] || ! "$install_dir/xray" version >/dev/null 2>&1; then
        echo -e "  ${red}Ошибка${reset}: Установленный Xray не запускается (повреждён или несовместим с архитектурой)"
        rm -f "$install_dir/xray" "$xray_archive"
        rm -rf "$xtmp_dir"
        [ -f "$install_dir/xray_bak" ] && mv "$install_dir/xray_bak" "$install_dir/xray" && \
            echo -e "  ${yellow}Восстановлен${reset} предыдущий бинарник Xray"
        return 1
    fi

    rm -f "$install_dir/xray_bak"
    echo -e "  Xray ${green}успешно установлен${reset}"

    rm -f "$xray_archive"
    rm -rf "$xtmp_dir"

    # Фикс для новых ядер xray
    if [ -d "$xray_conf_dir" ]; then
        for file in "$xray_conf_dir"/*.json; do
            [ -f "$file" ] || continue
            grep -qE '"transport"\s*:' "$file" && mv "$file" "${file}.obsolete"
        done
    fi

    return 0
}