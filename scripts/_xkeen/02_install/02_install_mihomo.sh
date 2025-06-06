# Функция для установки Mihomo
install_mihomo() {
    echo -e "  ${yellow}Выполняется установка${reset} Mihomo. Пожалуйста, подождите..."

    # Определение переменных
    mihomo_archive="${mtmp_dir}/mihomo.gz"
    info_content=""
    error_content=""

    # Проверка наличия архива Mihomo
    if [ -f "${mihomo_archive}" ]; then
        info_content="[info] Архив Mihomo найден\n"

        if [ -f "$install_dir/mihomo" ]; then
            mv "$install_dir/mihomo" "$install_dir/mihomo_bak"
        fi

        # Распаковка архива Mihomo
        if [ -d "${mtmp_dir}/mihomo" ]; then
            rm -r "${mtmp_dir}/mihomo"
        fi

        if gzip -d "${mihomo_archive}"; then
            info_content="${info_content}[info] Распаковка архива Mihomo выполнена\n"
            
            # Перемещение файла Mihomo
            if mv "${mtmp_dir}/mihomo" $install_dir/; then
                info_content="${info_content}[info] Mihomo успешно установлен в $install_dir/\n"
                
                # Установка исполняемых прав для mihomo
                if chmod +x $install_dir/mihomo; then
                    info_content="${info_content}[info] Установлены исполняемые права для Mihomo\n"
                else
                    error_content="${error_content}[error] Ошибка при установке исполняемых прав для Mihomo\n"
                fi
            else
                error_content="${error_content}[error] Ошибка при перемещении Mihomo\n"
            fi
        else
            error_content="${error_content}[error] Ошибка при распаковке архива Mihomo\n"
        fi

        # Удаление временных файлов
        if rm -rf "${mtmp_dir}/mihomo"; then
            info_content="${info_content}[info] Временные файлы удалены\n"
        else
            error_content="${error_content}[error] Ошибка при удалении временных файлов\n"
        fi

    else
        error_content="[error] Архив Mihomo не найден\n"
    fi

    # Запись информации и ошибок в соответствующие логи
    [ -n "${info_content}" ] && echo -e "${info_content}" >> "${xkeen_info_log}"
    [ -n "${error_content}" ] && echo -e "${error_content}" >> "${xkeen_error_log}"
}