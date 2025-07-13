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
    find /opt/etc/xray/dat -type f | while read -r file; do
        echo "$file" >> xray_s.list
    done

    find /opt/etc/xray/configs -type f | while read -r file; do
        echo "$file" >> xray_s.list
    done

    find /opt/var/log/xray -type f | while read -r file; do
        echo "$file" >> xray_s.list
    done

    # Добавление дополнительных путей
    echo "/opt/var/log/xray" >> xray_s.list
    echo "/opt/etc/xray/configs" >> xray_s.list
    echo "/opt/etc/xray/dat" >> xray_s.list
    echo "/opt/etc/xray" >> xray_s.list
    echo "/opt/sbin/xray" >> xray_s.list
    echo "/opt/etc/init.d/S24xray" >> xray_s.list
    echo "/opt/etc/init.d/S99xkeenstart" >> xray_s.list
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
    echo -e "\n$(cat new_entry.txt)" >> "$status_file"
}

register_xray_initd() {
    initd_file="${initd_dir}/S24xray"
    start_file="${initd_dir}/S99xkeenstart"
    s24xray_filename="${current_datetime}_S24xray"
    s99start_filename="${current_datetime}_S99xkeenstart"
    backup_path="${backups_dir}/${s24xray_filename}"
    backup_paths="${backups_dir}/${s99start_filename}"
    script_file="${xinstall_dir}/07_install_register/04_register_init.sh"
    variables_to_extract="name_client name_policy table_id table_mark port_dns ipv4_proxy ipv4_exclude ipv6_proxy ipv6_exclude port_donor port_exclude start_attempts start_auto check_fd arm64_fd other_fd delay_fd"
    temp_file=$(mktemp)

    if [ -f "${start_file}" ]; then
        mv "${start_file}" "${backup_paths}"
        if grep -q "^autostart=" "${backup_paths}"; then
            autostart_value=$(grep "^autostart=" "${backup_paths}" | head -n 1 | cut -d'=' -f2)
        fi
        if grep -q "^start_delay=" "${backup_paths}"; then
            start_delay_value=$(grep "^start_delay=" "${backup_paths}" | head -n 1 | cut -d'=' -f2)
        fi
    fi

    autostart="${autostart_value:-\"on\"}"
    start_delay="${start_delay_value:-20}"

    if [ ! -e "${initd_file}" ]; then
        cp "${script_file}" "${initd_file}"
        chmod +x "${initd_file}"
        echo -e "  Файл автозапуска ${yellow}создан и обновлен${reset}"
    else
        mv "${initd_file}" "${backup_path}"
        cat "${script_file}" > "${initd_file}"

        for var in $variables_to_extract; do
            if grep -q "^${var}=" "${backup_path}"; then
                value=$(grep "^${var}=" "${backup_path}" | head -n 1)
                position=$(grep -n "^${var}=" "${initd_file}" | head -n 1 | cut -d: -f1)

                if [ -n "$position" ]; then
                    sed -i "${position}s#.*#${value}#" "${initd_file}"
                fi
            fi
        done
    fi

    chmod +x "${initd_file}"

}

register_autostart() {
    [ -f "/opt/etc/init.d/S99xkeenrestart" ] && rm "/opt/etc/init.d/S99xkeenrestart"
    cat << EOF > "${initd_dir}/S99xkeenstart"
#!/bin/sh
#
autostart=${autostart}
start_delay=${start_delay}
#
log_info_router() {
    logger -p notice -t "XKeen" "\$1"
}
[ -f "/opt/etc/init.d/S99xkeenrestart" ] && rm "/opt/etc/init.d/S99xkeenrestart"
if [ "\${autostart}" = "on" ]; then
    HOST="ya.ru"
    while true; do
        log_info_router "Проверка доступности интернета"
        ping -c 1 "\$HOST" > /dev/null 2>&1
        if [ \$? -eq 0 ]; then
            log_info_router "Интернет доступен, выполняется запуск проксирования"
            touch "/tmp/start_fd"
            sleep \$start_delay
            /opt/etc/init.d/S24xray restart on
            break
        else
            log_info_router "Интернет не доступен, ожидание доступности..."
        fi
        sleep 5
    done
fi
EOF

    chmod +x "${initd_dir}/S99xkeenstart"
}