print_log_status() {
    local status_code=$1
    local success_msg=$2
    local error_msg=$3

    if [ "$status_code" -eq 0 ]; then
        echo -e "  ${green}Успешно${reset}: $success_msg"
    else
        echo -e "  ${red}Ошибка${reset}: $error_msg"
    fi
}

# Обратная связь в консоль
logs_cpu_info_console() {
    echo
    echo -e "  Набор инструкций процессора: ${yellow}$architecture${reset}"
    
    case "$architecture" in
        arm64-v8a|mips32le|mips32)
            echo -e "  Процессор ${green}поддерживается${reset} XKeen"
            ;;
        *)
            echo -e "  Процессор ${red}не поддерживается${reset} XKeen"
            ;;
    esac
}

logs_delete_configs_info_console() {
    local deleted_files=""
    
    if [ -d "$install_conf_dir" ]; then
        deleted_files=$(find "$install_conf_dir" -maxdepth 1 -name '*.json' -type f)
    fi

    if [ -z "$deleted_files" ]; then
        echo -e "  ${green}Успешно${reset}: Все конфигурационные файлы Xray удалены"
    else
        echo -e "  ${red}Ошибка${reset}: Не удалены следующие конфигурационные файлы:"
        for file in $deleted_files; do
            echo -e "    $file"
        done
    fi
}

logs_delete_geosite_info_console() {
    echo -e "  ${yellow}Проверка${reset} выполнения операции"
    for file in "geosite_antifilter.dat" "geosite_v2fly.dat" "geosite_zkeen.dat"; do
        [ ! -f "$geo_dir/$file" ]
        print_log_status $? "Файл $file отсутствует в директории '$geo_dir'" "Файл $file не удален"
    done
}

logs_delete_geoip_info_console() {
    echo -e "  ${yellow}Проверка${reset} выполнения операции"
    for file in "geoip_antifilter.dat" "geoip_v2fly.dat" "geoip_zkeenip.dat"; do
        [ ! -f "$geo_dir/$file" ]
        print_log_status $? "Файл $file отсутствует в директории '$geo_dir'" "Файл $file не удален"
    done
}

logs_delete_geoipset_info_console() {
    echo -e "  ${yellow}Проверка${reset} выполнения операции"
    
    [ ! -f "$ru_exclude_ipv4" ]
    print_log_status $? "Файл ru_exclude_ipv4.lst отсутствует в директории '$ipset_cfg'" "Файл ru_exclude_ipv4.lst не удален"
    
    [ ! -f "$ru_exclude_ipv6" ]
    print_log_status $? "Файл ru_exclude_ipv6.lst отсутствует в директории '$ipset_cfg'" "Файл ru_exclude_ipv6.lst не удален"
}

# Проверки регистрации XKeen

logs_register_xkeen_status_info_console() {
    grep -q "Package: xkeen" "$status_file"
    print_log_status $? "Запись XKeen найдена в '$status_file'" "Запись XKeen не найдена в '$status_file'"
}

logs_register_xkeen_control_info_console() {
    [ -f "$register_dir/xkeen.control" ]
    print_log_status $? "Файл xkeen.control найден в директории '$register_dir/'" "Файл xkeen.control не найден в директории '$register_dir/'"
}

logs_register_xkeen_list_info_console() {
    [ -f "$register_dir/xkeen.list" ]
    print_log_status $? "Файл xkeen.list найден в директории '$register_dir/'" "Файл xkeen.list не найден в директории '$register_dir/'"
}

logs_register_xkeen_initd_info_console() {
    [ -f "$initd_file" ]
    print_log_status $? "init скрипт XKeen найден в директории '$initd_dir/'" "init скрипт XKeen не найден в директории '$initd_dir/'"
}

logs_delete_register_xkeen_info_console() {
    [ ! -f "$register_dir/xkeen.list" ]
    print_log_status $? "Файл xkeen.list не найден в директории '$register_dir/'" "Файл xkeen.list найден в директории '$register_dir/'"

    [ ! -f "$register_dir/xkeen.control" ]
    print_log_status $? "Файл xkeen.control не найден в директории '$register_dir/'" "Файл xkeen.control найден в директории '$register_dir/'"

    ! grep -q 'Package: xkeen' "$status_file"
    print_log_status $? "Регистрация пакета xkeen не обнаружена в '$status_file'" "Регистрация пакета xkeen обнаружена в '$status_file'"
}

# Проверки регистрации Xray

logs_register_xray_status_info_console() {
    grep -q "Package: xray_s" "$status_file"
    print_log_status $? "Запись Xray найдена в '$status_file'" "Запись Xray не найдена в '$status_file'"
}

logs_register_xray_control_info_console() {
    [ -f "$register_dir/xray_s.control" ]
    print_log_status $? "Файл xray_s.control найден в директории '$register_dir/'" "Файл xray_s.control не найден в директории '$register_dir/'"
}

logs_register_xray_list_info_console() {
    [ -f "$register_dir/xray_s.list" ]
    print_log_status $? "Файл xray_s.list найден в директории '$register_dir/'" "Файл xray_s.list не найден в директории '$register_dir/'"
}

logs_delete_register_xray_info_console() {
    [ ! -f "$register_dir/xray_s.list" ]
    print_log_status $? "Файл xray_s.list не найден в директории '$register_dir/'" "Файл xray_s.list найден в директории '$register_dir/'"

    [ ! -f "$register_dir/xray_s.control" ]
    print_log_status $? "Файл xray_s.control не найден в директории '$register_dir/'" "Файл xray_s.control найден в директории '$register_dir/'"

    ! grep -q 'Package: xray_s' "$status_file"
    print_log_status $? "Регистрация пакета xray не обнаружена в '$status_file'" "Регистрация пакета xray обнаружена в '$status_file'"
}

# Проверки регистрации Mihomo

logs_register_mihomo_status_info_console() {
    grep -q "Package: mihomo" "$status_file"
    print_log_status $? "Запись mihomo найдена в '$status_file'" "Запись mihomo не найдена в '$status_file'"
}

logs_register_mihomo_control_info_console() {
    [ -f "$register_dir/mihomo_s.control" ]
    print_log_status $? "Файл mihomo_s.control найден в директории '$register_dir/'" "Файл mihomo_s.control не найден в директории '$register_dir/'"
}

logs_register_mihomo_list_info_console() {
    [ -f "$register_dir/mihomo_s.list" ]
    print_log_status $? "Файл mihomo_s.list найден в директории '$register_dir/'" "Файл mihomo_s.list не найден в директории '$register_dir/'"
}

logs_delete_register_mihomo_info_console() {
    [ ! -f "$register_dir/mihomo_s.list" ]
    print_log_status $? "Файл mihomo_s.list не найден в директории '$register_dir/'" "Файл mihomo_s.list найден в директории '$register_dir/'"

    [ ! -f "$register_dir/mihomo_s.control" ]
    print_log_status $? "Файл mihomo_s.control не найден в директории '$register_dir/'" "Файл mihomo_s.control найден в директории '$register_dir/'"

    ! grep -q 'Package: mihomo_s' "$status_file"
    print_log_status $? "Регистрация пакета mihomo не обнаружена в '$status_file'" "Регистрация пакета mihomo обнаружена в '$status_file'"
}

# Проверки регистрации YQ

logs_register_yq_status_info_console() {
    grep -q "Package: yq" "$status_file"
    print_log_status $? "Запись yq найдена в '$status_file'" "Запись yq не найдена в '$status_file'"
}

logs_register_yq_control_info_console() {
    [ -f "$register_dir/yq_s.control" ]
    print_log_status $? "Файл yq_s.control найден в директории '$register_dir/'" "Файл yq_s.control не найден в директории '$register_dir/'"
}

logs_register_yq_list_info_console() {
    [ -f "$register_dir/yq_s.list" ]
    print_log_status $? "Файл yq_s.list найден в директории '$register_dir/'" "Файл yq_s.list не найден в директории '$register_dir/'"
}

logs_delete_register_yq_info_console() {
    [ ! -f "$register_dir/yq_s.list" ]
    print_log_status $? "Файл yq_s.list не найден в директории '$register_dir/'" "Файл yq_s.list найден в директории '$register_dir/'"

    [ ! -f "$register_dir/yq_s.control" ]
    print_log_status $? "Файл yq_s.control не найден в директории '$register_dir/'" "Файл yq_s.control найден в директории '$register_dir/'"

    ! grep -q 'Package: yq_s' "$status_file"
    print_log_status $? "Регистрация пакета yq не обнаружена в '$status_file'" "Регистрация пакета yq обнаружена в '$status_file'"
}

# Остальные проверки

logs_delete_cron_geofile_info_console() {
    if [ -f "$cron_dir/$cron_file" ]; then
        ! grep -q "ug" "$cron_dir/$cron_file"
        print_log_status $? "Задача автоматического обновления GeoFile удалена из cron" "Задача автоматического обновления GeoFile не удалена из cron"
    fi
}