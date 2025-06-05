# Функция для установки Xray
install_xray() {
    # Проверка наличия файла Xray и создание резервной копии при необходимости
    [ -f "$install_dir/xray" ] && backup_xray

    echo -e "  ${yellow}Выполняется установка${reset} Xray. Пожалуйста, подождите..."

    # Определение переменных
    xray_archive="${xtmp_dir}/xray.zip"
    info_content=""
    error_content=""

    # Проверка наличия архива Xray
    if [ -f "${xray_archive}" ]; then
        info_content="[info] Архив Xray найден\n"

        if [ -f "$install_dir/xray" ]; then
            mv "$install_dir/xray" "$install_dir/xray_bak"
        fi

        # Распаковка архива Xray
        if [ -d "${xtmp_dir}/xray" ]; then
            rm -r "${xtmp_dir}/xray"
        fi

        if unzip -q "${xray_archive}" -d "${xtmp_dir}/xray"; then
            info_content="${info_content}[info] Распаковка архива Xray выполнена\n"
            
            # Перемещение файла Xray
            if mv "${xtmp_dir}/xray/xray" $install_dir/; then
                info_content="${info_content}[info] Xray успешно установлен в $install_dir/\n"
                
                # Установка исполняемых прав для Xray
                if chmod +x $install_dir/xray; then
                    info_content="${info_content}[info] Установлены исполняемые права для Xray\n"
                else
                    error_content="${error_content}[error] Ошибка при установке исполняемых прав для Xray\n"
                fi
            else
                error_content="${error_content}[error] Ошибка при перемещении Xray\n"
            fi
        else
            error_content="${error_content}[error] Ошибка при распаковке архива Xray\n"
        fi

        # Удаление архива Xray
        if rm "${xray_archive}"; then
            info_content="${info_content}[info] Архив Xray удален\n"
        else
            error_content="${error_content}[error] Ошибка при удалении архива Xray\n"
        fi

        # Удаление временных файлов
        if rm -rf "${xtmp_dir}/xray"; then
            info_content="${info_content}[info] Временные файлы удалены\n"
        else
            error_content="${error_content}[error] Ошибка при удалении временных файлов\n"
        fi

    else
        error_content="[error] Архив Xray не найден\n"
    fi

    # Запись информации и ошибок в соответствующие логи
    [ -n "${info_content}" ] && echo -e "${info_content}" >> "${xkeen_info_log}"
    [ -n "${error_content}" ] && echo -e "${error_content}" >> "${xkeen_error_log}"
}