# Регистрация xray
register_xray_control() {

    # Создание файла xray_s.control
    cat << EOF > "$register_dir/xray_s.control"
Package: xray_s
Version: $xray_current_version
Depends: libc, libssp, librt, libpthread, ca-bundle
Source: XTLS Team
SourceName: xray_s
Section: net
SourceDateEpoch: $source_date_epoch
Maintainer: Skrill / jameszero
Architecture: $status_architecture
Installed-Size: $installed_size
Description: A unified platform for anti-censorship.
EOF
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
    # Генерация новой записи
    echo "Package: xray_s" > new_entry.txt
    echo "Version: $xray_current_version" >> new_entry.txt
    echo "Depends: libc, libssp, librt, libpthread, ca-bundle" >> new_entry.txt
    echo "Status: install user installed" >> new_entry.txt
    echo "Architecture: $status_architecture" >> new_entry.txt
    echo "Installed-Time: $(date +%s)" >> new_entry.txt

    # Чтение существующего содержимого файла "status"
    existing_content=$(cat "$status_file")

    # Объединение существующего содержимого и новой записи
    echo "" >> "$status_file"
    cat new_entry.txt >> "$status_file"
    echo "" >> "$status_file"
    sed -i '/^$/{N;/^\n$/D}' "$status_file"
}