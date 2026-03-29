# Регистрация xray
register_xray_control() {
    write_opkg_control \
        "xray_s" \
        "$xray_current_version" \
        "libc, libssp, librt, libpthread, ca-bundle" \
        "XTLS Team" \
        "xray_s" \
        "Skrill / jameszero" \
        "A unified platform for anti-censorship."
}

register_xray_list() {
    cd "$register_dir/" || exit
    touch xray_s.list

    # Генерация списка файлов
    find /opt/etc/xray/dat -maxdepth 1 -name "*.dat" -type f | while read -r file; do
        echo "$file" >> xray_s.list
    done

    find /opt/etc/xray/configs -maxdepth 1 -name "*.json" -type f | while read -r file; do
        echo "$file" >> xray_s.list
    done

    find /opt/var/log/xray -maxdepth 1 -name "*.log" -type f | while read -r file; do
        echo "$file" >> xray_s.list
    done

    # Добавление дополнительных путей
    echo "/opt/var/log/xray" >> xray_s.list
    echo "/opt/etc/xray/configs" >> xray_s.list
    echo "/opt/etc/xray/dat" >> xray_s.list
    echo "/opt/etc/xray" >> xray_s.list
    echo "/opt/sbin/xray" >> xray_s.list
}

register_xray_status() {
    write_opkg_status \
        "xray_s" \
        "$xray_current_version" \
        "libc, libssp, librt, libpthread, ca-bundle"
}
