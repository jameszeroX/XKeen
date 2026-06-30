# Регистрация xray
register_xray_control() {
    write_opkg_control \
        "xray_s" \
        "$xray_current_version" \
        "ca-bundle" \
        "XTLS Team" \
        "xray_s" \
        "Skrill / jameszero" \
        "A unified platform for anti-censorship."
}

register_xray_list() {
    cd "$register_dir/" || exit
    touch xray_s.list

    # Генерация списка файлов
    {
        find "$geo_dir"       -maxdepth 1 -name "*.dat"  -type f
        find "$xray_conf_dir" -maxdepth 1 -name "*.json" -type f
        find "$xray_log_dir"  -maxdepth 1 -name "*.log"  -type f
        # Добавление дополнительных путей
        echo "$xray_log_dir"
        echo "$xray_conf_dir"
        echo "$geo_dir"
        dirname "$xray_conf_dir"
        echo "$install_dir/xray"
    } >> xray_s.list
}

register_xray_status() {
    write_opkg_status \
        "xray_s" \
        "$xray_current_version" \
        "ca-bundle"
}
