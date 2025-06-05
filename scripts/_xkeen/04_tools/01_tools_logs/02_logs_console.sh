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
        echo -e "    ${green}Успешно:${reset} Все конфигурационные файлы Xray удалены"
    else
        echo -e "    ${red}Ошибка:${reset} Не удалены следующие конфигурационные файлы:"
        for file in $deleted_files; do
            echo -e "     $file"
        done
    fi
}

logs_delete_geoip_info_console() {
    info_content=""
    error_content=""

    if [ -f "$geo_dir/geoip_antifilter.dat" ]; then
        error_content="     ${red}Ошибка:${reset} Файл geoip_antifilter.dat не удален\n"
    else
        info_content="     ${green}Успешно:${reset} Файл geoip_antifilter.dat отсутствует в директории '$geo_dir'\n"
    fi

    if [ -f "$geo_dir/geoip_v2fly.dat" ]; then
        error_content="${error_content}     ${red}Ошибка:${reset} Файл geoip_v2fly.dat не удален\n"
    else
        info_content="${info_content}     ${green}Успешно:${reset} Файл geoip_v2fly.dat отсутствует в директории '$geo_dir'\n"
    fi

    if [ -f "$geo_dir/geoip_zkeenip.dat" ]; then
        error_content="${error_content}     ${red}Ошибка:${reset} Файл geoip_zkeenip.dat не удален\n"
    else
        info_content="${info_content}     ${green}Успешно:${reset} Файл geoip_zkeenip.dat отсутствует в директории '$geo_dir'\n"
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
        error_content="     ${red}Ошибка:${reset} Файл geosite_antifilter.dat не удален\n"
    else
        info_content="     ${green}Успешно:${reset} Файл geosite_antifilter.dat отсутствует в директории '$geo_dir'\n"
    fi

    if [ -f "$geo_dir/geosite_v2fly.dat" ]; then
        error_content="${error_content}     ${red}Ошибка:${reset} Файл geosite_v2fly.dat не удален\n"
    else
        info_content="${info_content}     ${green}Успешно:${reset} Файл geosite_v2fly.dat отсутствует в директории '$geo_dir'\n"
    fi

    if [ -f "$geo_dir/geosite_zkeen.dat" ]; then
        error_content="${error_content}     ${red}Ошибка:${reset} Файл geosite_zkeen.dat не удален\n"
    else
        info_content="${info_content}     ${green}Успешно:${reset} Файл geosite_zkeen.dat отсутствует в директории '$geo_dir'\n"
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
        info_content="     ${green}Успешно:${reset} Запись Xkeen найдена в '$status_file'"
    else
        error_content="     ${red}Ошибка:${reset} Запись Xkeen не найдена в '$status_file'"
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
        info_content="     ${green}Успешно:${reset} Файл xkeen.control найден в директории '$register_dir/'"
    else
        error_content="     ${red}Ошибка:${reset} Файл xkeen.control не найден в директории '$register_dir/'"
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
        error_content="     ${red}Ошибка:${reset} Файл xkeen.list не найден в директории '$register_dir/'"
    else
        info_content="     ${green}Успешно:${reset} Файл xkeen.list найден в директории '$register_dir/'"
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
        info_content="     ${green}Успешно:${reset} Файл xkeen.list не найден в директории '$register_dir/'"
    else
        error_content="     ${red}Ошибка:${reset} Файл xkeen.list найден в директории '$register_dir/'"
    fi

    if [ ! -f "$register_dir/xkeen.control" ]; then
        info_content="${info_content}\n     ${green}Успешно:${reset} Файл xkeen.control не найден в директории '$register_dir/'"
    else
        error_content="${error_content}\n     ${red}Ошибка:${reset} Файл xkeen.control найден в директории '$register_dir/'"
    fi

    if ! grep -q 'Package: xkeen' "$status_file"; then
        info_content="${info_content}\n     ${green}Успешно:${reset} Регистрация пакета xkeen не обнаружена в '$status_file'"
    else
        error_content="${error_content}\n     ${red}Ошибка:${reset} Регистрация пакета xkeen обнаружена в '$status_file'"
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
        info_content="     ${green}Успешно:${reset} init скрипт Xray найден в директории '$initd_dir/'"
    else
        error_content="     ${red}Ошибка:${reset} init скрипт Xray не найден в директории '$initd_dir/'"
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
        error_content="     ${red}Ошибка:${reset} Файл xray_s.list не найден в директории '$register_dir/'"
    else
        info_content="     ${green}Успешно:${reset} Файл xray_s.list найден в директории '$register_dir/'"
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
        info_content="     ${green}Успешно:${reset} Запись Xray найдена в '$status_file'"
    else
        error_content="     ${red}Ошибка:${reset} Запись Xray не найдена в '$status_file'"
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
        info_content="     ${green}Успешно:${reset} Файл xray_s.control найден в директории '$register_dir/'"
    else
        error_content="     ${red}Ошибка:${reset} Файл xray_s.control не найден в директории '$register_dir/'"
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
        info_content="     ${green}Успешно:${reset} Файл xray_s.list не найден в директории '$register_dir/'"
    else
        error_content="     ${red}Ошибка:${reset} Файл xray_s.list найден в директории '$register_dir/'"
    fi

    if [ ! -f "$register_dir/xray_s.control" ]; then
        info_content="${info_content}\n     ${green}Успешно:${reset} Файл xray_s.control не найден в директории '$register_dir/'"
    else
        error_content="${error_content}\n     ${red}Ошибка:${reset} Файл xray_s.control найден в директории '$register_dir/'"
    fi

    if ! grep -q 'Package: xray' "$status_file"; then
        info_content="${info_content}\n     ${green}Успешно:${reset} Регистрация пакета xray не обнаружена в '$status_file'"
    else
        error_content="${error_content}\n     ${red}Ошибка:${reset} Регистрация пакета xray обнаружена в '$status_file'"
    fi

    if [ -n "$info_content" ]; then
        echo -e "$info_content"
    fi

    if [ -n "$error_content" ]; then
        echo -e "$error_content"
    fi
}

logs_install_cron_info_console() {
    info_content=""
    error_content=""
    last_line=""

    cron_file_path="$cron_dir/$cron_file"
    
    if [ -f "$cron_file_path" ]; then
        if [ -n "$chose_all_cron_time" ] || [ -n "$chose_geofile_cron_time" ] || [ -n "$chose_xkeen_cron_time" ] || [ -n "$chose_xray_cron_time" ]; then
            if [ -n "$chose_all_cron_time" ] || [ -n "$chose_geofile_cron_time" ]; then
                if grep -q "$install_dir/xkeen.*-ug" "$cron_file_path"; then
                    task="GeoFile"
                    cron_entry=$(grep "$install_dir/xkeen.*-ug" "$cron_file_path")
                    info_content="     ${green}Успешно:${reset} Запись для задачи автоматического обновления $task существует"
                    info_content="${info_content}\n     ${green}Успешно:${reset} $cron_entry"
                    last_line="$cron_entry"
                else
                    error_content="     ${red}Ошибка:${reset} Запись для задачи автоматического обновления GeoFile не существует в cron файле"
                fi
            fi

            if [ -n "$chose_all_cron_time" ] || [ -n "$chose_xkeen_cron_time" ]; then
                if grep -q "$install_dir/xkeen.*-uk" "$cron_file_path"; then
                    task="XKeen"
                    cron_entry=$(grep "$install_dir/xkeen.*-uk" "$cron_file_path")
                    info_content="${info_content}\n     ${green}Успешно:${reset} Запись для задачи автоматического обновления $task существует"
                    info_content="${info_content}\n     ${green}Успешно:${reset} $cron_entry"
                    last_line="$cron_entry"
                else
                    error_content="${error_content}\n     ${red}Ошибка:${reset} Запись для задачи автоматического обновления Xkeen не существует в cron файле"
                fi
            fi

            if [ -n "$chose_all_cron_time" ] || [ -n "$chose_xray_cron_time" ]; then
                if grep -q "$install_dir/xkeen.*-ux" "$cron_file_path"; then
                    task="Xray"
                    cron_entry=$(grep "$install_dir/xkeen.*-ux" "$cron_file_path")
                    info_content="${info_content}\n     ${green}Успешно:${reset} Запись для задачи автоматического обновления $task существует"
                    info_content="${info_content}\n     ${green}Успешно:${reset} $cron_entry"
                    last_line="$cron_entry"
                else
                    error_content="${error_content}\n     ${red}Ошибка:${reset} Запись для задачи автоматического обновления Xray не существует в cron файле"
                fi
            fi
        fi
    else
        error_content="     ${red}Ошибка:${reset} Файл cron не найден"
    fi

    if [ -n "$error_content" ]; then
        echo ""
        echo -e "$error_content"
        if [ -n "$last_line" ]; then
            echo ""
        fi
    fi

if [ -n "$info_content" ]; then
        echo ""
        echo -e "$info_content"
        if [ -n "$last_line" ]; then
            echo ""
        fi
    fi
}

logs_install_geoip_info_console() {
    info_content=""
    error_content=""

    if [ "$install_antifilter_geoip" = true ]; then
        if [ -f "$geo_dir/geoip_antifilter.dat" ]; then
            info_content="     ${green}Успешно:${reset} GeoIP AntiFilter установлена"
        else
            error_content="     ${red}Ошибка:${reset} Не удалось установить GeoIP базу AntiFilter"
        fi
    fi

    if [ "$install_v2fly_geoip" = true ]; then
        if [ -f "$geo_dir/geoip_v2fly.dat" ]; then
            info_content="${info_content}\n     ${green}Успешно:${reset} GeoIP v2fly установлена"
        else
            error_content="${error_content}\n     ${red}Ошибка:${reset} Не удалось установить GeoIP базу v2fly"
        fi
    fi

    if [ "$install_zkeenip_geoip" = true ]; then
        if [ -f "$geo_dir/geoip_zkeenip.dat" ]; then
            info_content="${info_content}\n     ${green}Успешно:${reset} GeoIP ZkeenIP установлена"
        else
            error_content="${error_content}\n     ${red}Ошибка:${reset} Не удалось установить GeoIP базу ZkeenIP"
        fi
    fi

    if [ "$update_antifilter_geoip" = true ]; then
        if [ -f "$geo_dir/geoip_antifilter.dat" ]; then
            info_content="${info_content}\n     ${green}Успешно:${reset} GeoIP AntiFilter обновлена"
        else
            error_content="${error_content}\n     ${red}Ошибка:${reset} GeoIP AntiFilter не установлена. Поэтому не может быть обновлена"
        fi
    fi

    if [ "$update_v2fly_geoip" = true ]; then
        if [ -f "$geo_dir/geoip_v2fly.dat" ]; then
            info_content="${info_content}\n     ${green}Успешно:${reset} GeoIP v2fly обновлена"
        else
            error_content="${error_content}\n     ${red}Ошибка:${reset} GeoIP v2fly не установлена. Поэтому не может быть обновлена"
        fi
    fi

    if [ "$update_zkeenip_geoip" = true ]; then
        if [ -f "$geo_dir/geoip_zkeenip.dat" ]; then
            info_content="${info_content}\n     ${green}Успешно:${reset} GeoIP ZkeenIP обновлена"
        else
            error_content="${error_content}\n     ${red}Ошибка:${reset} GeoIP ZkeenIP не установлена. Поэтому не может быть обновлена"
        fi
    fi

    if [ -n "$info_content" ] || [ -n "$error_content" ]; then
        echo ""
        if [ -n "$info_content" ]; then
            echo -e "$info_content"
        fi
        if [ -n "$error_content" ]; then
            echo -e "$error_content"
        fi
        echo ""
    fi
}

logs_install_geosite_info_console() {
    info_content=""
    error_content=""

    if [ "$install_antifilter_geosite" = true ]; then
        if [ -f "$geo_dir/geosite_antifilter.dat" ]; then
            info_content="${info_content}\n     ${green}Успешно:${reset} GeoSite AntiFilter установлена"
        else
            error_content="${error_content}\n     ${red}Ошибка:${reset} Не удалось установить GeoSite базу AntiFilter"
			fi
    fi

    if [ "$install_v2fly_geosite" = true ]; then
        if [ -f "$geo_dir/geosite_v2fly.dat" ]; then
            info_content="${info_content}\n     ${green}Успешно:${reset} GeoSite v2fly установлена"
        else
            error_content="${error_content}\n     ${red}Ошибка:${reset} Не удалось установить GeoSite базу v2fly"
        fi
    fi

    if [ "$install_zkeen_geosite" = true ]; then
        if [ -f "$geo_dir/geosite_zkeen.dat" ]; then
            info_content="${info_content}\n     ${green}Успешно:${reset} GeoSite Zkeen установлена"
        else
            error_content="${error_content}\n     ${red}Ошибка:${reset} Не удалось установить GeoSite базу Zkeen"
        fi
    fi

    if [ "$update_antifilter_geosite" = true ]; then
        if [ -f "$geo_dir/geosite_antifilter.dat" ]; then
            info_content="${info_content}\n     ${green}Успешно:${reset} GeoSite AntiFilter обновлена"
        else
            error_content="${error_content}\n     ${red}Ошибка:${reset} GeoSite AntiFilter не установлена. Поэтому не может быть обновлена"
        fi
    fi

    if [ "$update_v2fly_geosite" = true ]; then
        if [ -f "$geo_dir/geosite_v2fly.dat" ]; then
            info_content="${info_content}\n     ${green}Успешно:${reset} GeoSite v2fly обновлена"
        else
            error_content="${error_content}\n     ${red}Ошибка:${reset} GeoSite v2fly не установлена. Поэтому не может быть обновлена"
        fi
    fi

    if [ "$update_zkeen_geosite" = true ]; then
        if [ -f "$geo_dir/geosite_zkeen.dat" ]; then
            info_content="${info_content}\n     ${green}Успешно:${reset} GeoSite Zkeen обновлена"
        else
            error_content="${error_content}\n     ${red}Ошибка:${reset} GeoSite Zkeen не установлена. Поэтому не может быть обновлена"
        fi
    fi

    if [ -n "$info_content" ] || [ -n "$error_content" ]; then
        echo ""
        if [ -n "$info_content" ]; then
            echo -e "$info_content"
        fi
        if [ -n "$error_content" ]; then
            echo -e "$error_content"
        fi
        echo ""
    fi
}

logs_install_configs_info_console() {
    info_content=""
    error_content=""

    if [ -d "$xkeen_conf_dir" ]; then
        xkeen_files="$xkeen_conf_dir"/*.json
        
        files_to_replace=""
        
        for file in $xkeen_files; do
            filename=$(basename "$file" .json)
            if [ -f "$install_conf_dir/$filename.json" ]; then
                files_to_replace="$files_to_replace $filename"
            fi
        done

        if [ -n "$files_to_replace" ]; then
            info_content="     ${green}Успешно:${reset} Файлы находящиеся в директории конфигураций Xray:\n"
            for filename in $files_to_replace; do
                info_content="${info_content}          $filename\n"
            done
        fi
    else
        error_content="     ${red}Ошибка:${reset} Директория $xkeen_conf_dir не найдена\n"
    fi

    if [ -n "$error_content" ] || [ -n "$info_content" ]; then
        if [ -n "$error_content" ]; then
            echo -e "$error_content"
        fi
        if [ -n "$info_content" ]; then
            echo -e "$info_content"
        fi
    fi
}

logs_delete_cron_geofile_info_console() {
    info_content=""
    
    if [ -f "$cron_dir/$cron_file" ]; then
        if grep -q "ug" "$cron_dir/$cron_file"; then
            error_content="     ${red}Ошибка:${reset} Задача автоматического обновления GeoFile не удалена из cron"
        else
            info_content="     ${green}Успешно:${reset} Задача автоматического обновления GeoFile удалена из cron"
        fi
        
        if [ -n "$info_content" ]; then
            echo -e "$info_content"
        elif [ -n "$error_content" ]; then
            echo -e "$error_content"
        fi
    fi
}

logs_delete_cron_xkeen_info_console() {
    info_content=""
    
    if [ -f "$cron_dir/$cron_file" ]; then
        if grep -q "uk" "$cron_dir/$cron_file"; then
            error_content="     ${red}Ошибка:${reset} Задача автоматического обновления XKeen не удалена из cron"
        else
            info_content="     ${green}Успешно:${reset} Задача автоматического обновления XKeen удалена из cron"
        fi
        
        if [ -n "$info_content" ]; then
            echo -e "$info_content"
        elif [ -n "$error_content" ]; then
            echo -e "$error_content"
        fi
    fi
}

logs_delete_cron_xray_info_console() {
    info_content=""
    
    if [ -f "$cron_dir/$cron_file" ]; then
        if grep -q "ux" "$cron_dir/$cron_file"; then
            error_content="     ${red}Ошибка:${reset} Задача автоматического обновления Xray не удалена из cron"
        else
            info_content="     ${green}Успешно:${reset} Задача автоматического обновления Xray удалена из cron"
        fi
        
        if [ -n "$info_content" ]; then
            echo -e "$info_content"
        elif [ -n "$error_content" ]; then
            echo -e "$error_content"
        fi
    fi
}
