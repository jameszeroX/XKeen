# Функция для установки Xkeen
install_xkeen() {
    xkeen_archive="${tmp_dir}/xkeen.tar"
    info_content=""
    error_content=""

    # Проверка наличия архива xkeen
    if [ -f "${xkeen_archive}" ]; then
        info_content="\t[info] Архив xkeen найден\n"
        
        # Временный скрипт для установки
        install_script=$(mktemp)
        cat <<EOF > "${install_script}"
#!/bin/sh

# Распаковка архива
tar xf "${xkeen_archive}" -C "${install_dir}" xkeen _xkeen

# Проверка наличия _xkeen в install_dir и его перемещение
if [ -d "${install_dir}/_xkeen" ]; then
    rm -rf "${install_dir}/.xkeen"
    mv "${install_dir}/_xkeen" "${install_dir}/.xkeen"
else
    echo -e "  ${red}Ошибка:${reset} _xkeen не была правильно перенесена"
fi

# Удаление архива
rm "${xkeen_archive}"
EOF

        chmod +x "${install_script}"
        "${install_script}"
        
        # Проверка успешности установки и запись информации в соответствующие логи
        if [ $? -eq 0 ]; then
            info_content="${info_content}\t[info] Установка xkeen успешно завершена"
            echo "" >> "${xkeen_info_log}"
            echo "[start] Установка xkeen" >> "${xkeen_info_log}"
            echo -e "${info_content}" >> "${xkeen_info_log}"
            echo "[end] Установка xkeen выполнена" >> "${xkeen_info_log}"
            echo "" >> "${xkeen_info_log}"
        else
            error_content="${error_content}\t[error] Ошибка при установке xkeen"
            echo "" >> "${xkeen_error_log}"
            echo "[start] Установка xkeen" >> "${xkeen_error_log}"
            echo -e "${error_content}" >> "${xkeen_error_log}"
            echo "[end] Установка xkeen выполнена" >> "${xkeen_error_log}"
            echo "" >> "${xkeen_error_log}"
        fi
        
        rm "${install_script}"

    else
        error_content="\t[error] Архив xkeen не найден\n"
    fi
}