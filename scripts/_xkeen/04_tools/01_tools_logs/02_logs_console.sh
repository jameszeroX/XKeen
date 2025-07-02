# Обратная связь в консоль

logs_cpu_info_console() {
        echo ""
        echo -e "  Набор инструкций процессора: ${yellow}$architecture${reset}"
	
    if [ -z "$architecture" ]; then
        echo -e "  Процессор ${red}не поддерживается${reset} XKeen"
    else
        echo -e "  Процессор ${green}поддерживается${reset} XKeen"
    fi
}

logs_delete_configs_info_console() {
    info_content=""
    error_content=""

    deleted_files=$(find "$install_conf_dir" -name "*.json" -type f)
    
    if [ -z "$deleted_files" ]; then
        echo -e "  ${green}Успешно:${reset} Все конфигурационные файлы Xray удалены"
    else
        echo -e "  ${red}Ошибка:${reset} Не удалены следующие конфигурационные файлы:"
        for file in $deleted_files; do
            echo -e "     $file"
        done
    fi
}

logs_delete_geoip_info_console() {
    info_content=""
    error_content=""

    if [ -f "$geo_dir/geoip_antifilter.dat" ]; then
        error_content="  ${red}Ошибка:${reset} Файл geoip_antifilter.dat не удален\n"
    else
        info_content="  ${green}Успешно:${reset} Файл geoip_antifilter.dat отсутствует в директории '$geo_dir'\n"
    fi

    if [ -f "$geo_dir/geoip_v2fly.dat" ]; then
        error_content="${error_content}  ${red}Ошибка:${reset} Файл geoip_v2fly.dat не удален\n"
    else
        info_content="${info_content}  ${green}Успешно:${reset} Файл geoip_v2fly.dat отсутствует в директории '$geo_dir'\n"
    fi

    if [ -f "$geo_dir/geoip_zkeenip.dat" ]; then
        error_content="${error_content}  ${red}Ошибка:${reset} Файл geoip_zkeenip.dat не удален\n"
    else
        info_content="${info_content}  ${green}Успешно:${reset} Файл geoip_zkeenip.dat отсутствует в директории '$geo_dir'\n"
    fi

    if [ -n "$error_content" ]; then
        echo -e "  ${yellow}Проверка${reset} выполнения операции"
        echo -e "$error_content"
    else
		echo -e "  ${yellow}Проверка${reset} выполнения операции"
        echo -e "$info_content"
    fi
}

logs_delete_geosite_info_console() {
    info_content=""
    error_content=""

    if [ -f "$geo_dir/geosite_antifilter.dat" ]; then
        error_content="  ${red}Ошибка:${reset} Файл geosite_antifilter.dat не удален\n"
    else
        info_content="  ${green}Успешно:${reset} Файл geosite_antifilter.dat отсутствует в директории '$geo_dir'\n"
    fi

    if [ -f "$geo_dir/geosite_v2fly.dat" ]; then
        error_content="${error_content}  ${red}Ошибка:${reset} Файл geosite_v2fly.dat не удален\n"
    else
        info_content="${info_content}  ${green}Успешно:${reset} Файл geosite_v2fly.dat отсутствует в директории '$geo_dir'\n"
    fi

    if [ -f "$geo_dir/geosite_zkeen.dat" ]; then
        error_content="${error_content}  ${red}Ошибка:${reset} Файл geosite_zkeen.dat не удален\n"
    else
        info_content="${info_content}  ${green}Успешно:${reset} Файл geosite_zkeen.dat отсутствует в директории '$geo_dir'\n"
    fi

    if [ -n "$error_content" ]; then
        echo -e "  ${yellow}Проверка${reset} выполнения операции"
        echo -e "$error_content"
    else
        echo -e "  ${yellow}Проверка${reset} выполнения операции"
        echo -e "$info_content"
    fi
}

logs_register_xkeen_status_info_console() {
    info_content=""
    error_content=""

    if grep -q "Package: xkeen" "$status_file"; then
        info_content="  ${green}Успешно:${reset} Запись Xkeen найдена в '$status_file'"
    else
        error_content="  ${red}Ошибка:${reset} Запись Xkeen не найдена в '$status_file'"
    fi
    
    if [ -n "$info_content" ]; then
		echo -e "$info_content"
    fi
    
    if [ -n "$error_content" ]; then
		echo -e "$error_content"
    fi
}

logs_register_xkeen_control_info_console() {
    info_content=""
    error_content=""

    if [ -f "$register_dir/xkeen.control" ]; then
        info_content="  ${green}Успешно:${reset} Файл xkeen.control найден в директории '$register_dir/'"
    else
        error_content="  ${red}Ошибка:${reset} Файл xkeen.control не найден в директории '$register_dir/'"
    fi
    
    if [ -n "$info_content" ]; then
        echo -e "$info_content"
    fi
    
    if [ -n "$error_content" ]; then
        echo -e "$error_content"
    fi
}

logs_register_xkeen_list_info_console() {
    info_content=""
    error_content=""
	
    cd "$register_dir/" || exit

    if [ ! -f "xkeen.list" ]; then
        error_content="  {red}Ошибка:${reset} Файл xkeen.list не найден в директории '$register_dir/'"
    else
        info_content="  ${green}Успешно:${reset} Файл xkeen.list найден в директории '$register_dir/'"
    fi

    if [ -n "$error_content" ]; then
        echo -e "$error_content"
    fi

    if [ -n "$info_content" ]; then
        echo -e "$info_content"
    fi
}

logs_delete_register_xkeen_info_console() {
    info_content=""
    error_content=""

    if [ ! -f "$register_dir/xkeen.list" ]; then
        info_content="  ${green}Успешно:${reset} Файл xkeen.list не найден в директории '$register_dir/'"
    else
        error_content="  ${red}Ошибка:${reset} Файл xkeen.list найден в директории '$register_dir/'"
    fi

    if [ ! -f "$register_dir/xkeen.control" ]; then
        info_content="${info_content}\n  ${green}Успешно:${reset} Файл xkeen.control не найден в директории '$register_dir/'"
    else
        error_content="${error_content}\n  ${red}Ошибка:${reset} Файл xkeen.control найден в директории '$register_dir/'"
    fi

    if ! grep -q 'Package: xkeen' "$status_file"; then
        info_content="${info_content}\n  ${green}Успешно:${reset} Регистрация пакета xkeen не обнаружена в '$status_file'"
    else
        error_content="${error_content}\n  ${red}Ошибка:${reset} Регистрация пакета xkeen обнаружена в '$status_file'"
    fi

    if [ -n "$error_content" ]; then
        echo -e "$error_content"
    fi

    if [ -n "$info_content" ]; then
        echo -e "$info_content"
    fi
}

logs_register_xray_initd_info_console() {
    info_content=""
    error_content=""

    initd_file="$initd_dir/S24xray"

    if [ -f "$initd_file" ]; then
        info_content="  ${green}Успешно:${reset} init скрипт Xray найден в директории '$initd_dir/'"
    else
        error_content="  ${red}Ошибка:${reset} init скрипт Xray не найден в директории '$initd_dir/'"
    fi

    if [ -n "$info_content" ]; then
        echo -e "$info_content"
    fi

    if [ -n "$error_content" ]; then
        echo -e "$error_content"
    fi
}

logs_register_xray_list_info_console() {
    info_content=""
    error_content=""
	
    cd "$register_dir/" || exit

    if [ ! -f "xray_s.list" ]; then
        error_content="  ${red}Ошибка:${reset} Файл xray_s.list не найден в директории '$register_dir/'"
    else
        info_content="  ${green}Успешно:${reset} Файл xray_s.list найден в директории '$register_dir/'"
    fi

    if [ -n "$error_content" ]; then
        echo -e "$error_content"
    fi

    if [ -n "$info_content" ]; then
        echo -e "$info_content"
    fi
}

logs_register_xray_status_info_console() {
    info_content=""
    error_content=""

    if grep -q "Package: xray" "$status_file"; then
        info_content="  ${green}Успешно:${reset} Запись Xray найдена в '$status_file'"
    else
        error_content="  ${red}Ошибка:${reset} Запись Xray не найдена в '$status_file'"
    fi
    
    if [ -n "$info_content" ]; then
        echo -e "$info_content"
    fi
    
    if [ -n "$error_content" ]; then
        echo -e "$error_content"
    fi
}

logs_register_xray_control_info_console() {
    info_content=""
    error_content=""
    
    control_file_path="$register_dir/xray_s.control"
    
    if [ -f "$control_file_path" ]; then
        info_content="  ${green}Успешно:${reset} Файл xray_s.control найден в директории '$register_dir/'"
    else
        error_content="  ${red}Ошибка:${reset} Файл xray_s.control не найден в директории '$register_dir/'"
    fi
    
    if [ -n "$info_content" ]; then
        echo -e "$info_content"
    fi

    if [ -n "$error_content" ]; then
        echo -e "$error_content"
    fi
}

logs_delete_register_xray_info_console() {
    info_content=""
    error_content=""

    if [ ! -f "$register_dir/xray_s.list" ]; then
        info_content="  ${green}Успешно:${reset} Файл xray_s.list не найден в директории '$register_dir/'"
    else
        error_content="  ${red}Ошибка:${reset} Файл xray_s.list найден в директории '$register_dir/'"
    fi

    if [ ! -f "$register_dir/xray_s.control" ]; then
        info_content="${info_content}\n  ${green}Успешно:${reset} Файл xray_s.control не найден в директории '$register_dir/'"
    else
        error_content="${error_content}\n  ${red}Ошибка:${reset} Файл xray_s.control найден в директории '$register_dir/'"
    fi

    if ! grep -q 'Package: xray' "$status_file"; then
        info_content="${info_content}\n  ${green}Успешно:${reset} Регистрация пакета xray не обнаружена в '$status_file'"
    else
        error_content="${error_content}\n  ${red}Ошибка:${reset} Регистрация пакета xray обнаружена в '$status_file'"
    fi

    if [ -n "$info_content" ]; then
        echo -e "$info_content"
    fi

    if [ -n "$error_content" ]; then
        echo -e "$error_content"
    fi
}

logs_delete_cron_geofile_info_console() {
    info_content=""
    
    if [ -f "$cron_dir/$cron_file" ]; then
        if grep -q "ug" "$cron_dir/$cron_file"; then
            error_content="  ${red}Ошибка:${reset} Задача автоматического обновления GeoFile не удалена из cron"
        else
            info_content="  ${green}Успешно:${reset} Задача автоматического обновления GeoFile удалена из cron"
        fi
        
        if [ -n "$info_content" ]; then
            echo -e "$info_content"
        elif [ -n "$error_content" ]; then
            echo -e "$error_content"
        fi
    fi
}
