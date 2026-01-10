# Регистрация XKeen

# Функция для создания файла xkeen.control
register_xkeen_control() {
	script_dir="$(cd "$(dirname "$0")" && pwd)"
	. "$script_dir/.xkeen/01_info/01_info_variable.sh"
	
    # Создание файла xkeen.control
    cat << EOF > "$register_dir/xkeen.control"
Package: xkeen
Version: $xkeen_current_version
Depends: jq, curl, lscpu, coreutils-uname, coreutils-nohup, iptables
Source: Skrill
SourceName: xkeen
Section: net
SourceDateEpoch: $source_date_epoch
Maintainer: Skrill / jameszero
Architecture: $status_architecture
Installed-Size: $installed_size
Description: The platform that makes Xray work.
EOF
}

register_xkeen_list() {
    cd "$register_dir/" || exit

    # Создание файла xkeen.list
    touch xkeen.list

    # Генерация списка файлов и директорий
    find /opt/sbin/.xkeen -mindepth 1 | while read -r entry; do
        echo "$entry" >> xkeen.list
    done

    # Добавление дополнительных путей
    echo "/opt/sbin/xkeen" >> xkeen.list
    echo "/opt/sbin/.xkeen" >> xkeen.list
    echo "/opt/etc/init.d/S99xkeen" >> xkeen.list
}

register_xkeen_status() {
    # Генерация новой записи
    echo "Package: xkeen" > new_entry.txt
    echo "Version: $xkeen_current_version" >> new_entry.txt
    echo "Depends: jq, curl, lscpu, coreutils-uname, coreutils-nohup, iptables" >> new_entry.txt
    echo "Status: install user installed" >> new_entry.txt
    echo "Architecture: $status_architecture" >> new_entry.txt
    echo "Installed-Time: $(date +%s)" >> new_entry.txt

    # Чтение существующего содержимого файла "status"
    existing_content=$(cat "$status_file")

    # Объединение существующего содержимого и новой записи
    printf "\n$(cat new_entry.txt)\n" >> "$status_file"
}

register_xkeen_initd() {
    initd_file="${initd_dir}/S99xkeen"
    old_initd_file="${initd_dir}/S24xray"
    old_start_file="${initd_dir}/S99xkeenstart"
    script_file="${xinstall_dir}/07_install_register/04_register_init.sh" 
    current_datetime=$(date "+%Y-%m-%d_%H-%M-%S")
    variables_to_extract="name_client name_policy table_id table_mark port_dns ipv4_proxy ipv4_exclude ipv6_proxy ipv6_exclude port_donor port_exclude start_attempts check_fd arm64_fd other_fd delay_fd backup ipv6_support"
    source_main_backup=""
    source_start_backup=""

    if [ -f "$initd_file" ]; then
        source_main_backup="${backups_dir}/${current_datetime}_S99xkeen"
        mv "$initd_file" "$source_main_backup"
        
    elif [ -f "$old_initd_file" ] || [ -f "$old_start_file" ]; then
        if [ -f "$old_initd_file" ]; then
            source_main_backup="${backups_dir}/${current_datetime}_S24xray"
            mv "$old_initd_file" "$source_main_backup"
        fi
        if [ -f "$old_start_file" ]; then
            source_start_backup="${backups_dir}/${current_datetime}_S99xkeenstart"
            mv "$old_start_file" "$source_start_backup"
        fi
    fi

    cp "$script_file" "$initd_file"

    if [ -n "$source_main_backup" ] || [ -n "$source_start_backup" ]; then
        autostart_val=""
        start_delay_val=""

        if [ -n "$source_start_backup" ] && [ -f "$source_start_backup" ]; then
            autostart_val=$(grep '^autostart=' "$source_start_backup" | head -n 1 | cut -d'=' -f2)
            start_delay_val=$(grep '^start_delay=' "$source_start_backup" | head -n 1 | cut -d'=' -f2)
        fi

        if [ -n "$source_main_backup" ] && [ -f "$source_main_backup" ]; then
            [ -z "$autostart_val" ] && autostart_val=$(grep '^start_auto=' "$source_main_backup" | head -n 1 | cut -d'=' -f2)
            [ -z "$start_delay_val" ] && start_delay_val=$(grep '^start_delay=' "$source_main_backup" | head -n 1 | cut -d'=' -f2)
        fi

        if [ -n "$autostart_val" ]; then
             sed -i "s|^start_auto=.*|start_auto=$autostart_val|" "$initd_file"
        fi
        if [ -n "$start_delay_val" ]; then
             sed -i "s|^start_delay=.*|start_delay=$start_delay_val|" "$initd_file"
        fi

        if [ -n "$source_main_backup" ] && [ -f "$source_main_backup" ]; then
            for var in $variables_to_extract; do
                if grep -q "^${var}=" "$source_main_backup"; then
                    value=$(grep "^${var}=" "$source_main_backup" | head -n 1)
                    escaped_value=$(printf '%s\n' "$value" | sed 's:[&/\]:\\&:g')
                    position=$(grep -n "^${var}=" "$initd_file" | head -n 1 | cut -d: -f1)
                    if [ -n "$position" ]; then
                        sed -i "${position}s#.*#${escaped_value}#" "$initd_file"
                    fi
                fi
            done
        fi
    fi

    chmod +x "$initd_file"
    if choice_backup_xkeen; then
        rm -f "$source_main_backup" "$source_start_backup"
    fi
}

# Миграция скрипта
register_xray_initd() {
    register_xkeen_initd
}
register_autostart() {
    :
}

# Создание конфигурации XKeen
create_xkeen_cfg() {
    if [ ! -d "${xkeen_cfg}" ]; then
        mkdir -p "${xkeen_cfg}"
    fi
    if [ -f "/opt/etc/xkeen_exclude.lst" ] && [ ! -f "${xkeen_cfg}/ip_exclude.lst" ]; then
        mv "/opt/etc/xkeen_exclude.lst" "${xkeen_cfg}/ip_exclude.lst"
    elif [ ! -f "${xkeen_cfg}/ip_exclude.lst" ]; then
        cat << EOF > "${xkeen_cfg}/ip_exclude.lst"
#192.168.0.0/16
#2001:db8::/32

# Добавьте необходимые IP и подсети без комментария # для исключения их из проксирования
EOF
    fi

    if [ ! -f "${xkeen_cfg}/port_exclude.lst" ]; then
        cat << EOF > "${xkeen_cfg}/port_exclude.lst"
#

# Одновременно использовать порты проксирования и исключать порты нельзя
# Приоритет у портов проксирования
EOF
    fi

    if [ ! -f "${xkeen_cfg}/port_proxying.lst" ]; then
        cat << EOF > "${xkeen_cfg}/port_proxying.lst"
#80
#443
#596:599

# (Раскомментируйте/добавьте по образцу) единичные порты и диапазоны для проскирования
EOF
    fi
}

