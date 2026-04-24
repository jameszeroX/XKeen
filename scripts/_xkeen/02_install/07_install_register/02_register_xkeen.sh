# Регистрация XKeen

# Функция для создания файла xkeen.control
register_xkeen_control() {
    write_opkg_control \
        "xkeen" \
        "$xkeen_current_version" \
        "jq, curl, coreutils-uname, coreutils-nohup, iptables, ipset" \
        "Skrill" \
        "xkeen" \
        "Skrill / jameszero" \
        "The platform that makes Xray work."
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
    echo "$initd_file" >> xkeen.list
}

register_xkeen_status() {
    write_opkg_status \
        "xkeen" \
        "$xkeen_current_version" \
        "jq, curl, coreutils-uname, coreutils-nohup, iptables, ipset"
}


fixed_register_packages() {
	awk 'BEGIN {RS=""; ORS="\n\n"} {gsub(/\n\n+/,"\n\n")}1' "$status_file" > tmp_status_file && mv tmp_status_file "$status_file"
}

register_xkeen_initd() {
    old_initd_file="${initd_dir}/S24xray"
    pre_initd_file="${initd_dir}/S99xkeen"
    old_start_file="${initd_dir}/S99xkeenstart"
    script_file="${xinstall_dir}/07_install_register/04_register_init.sh" 
    current_datetime=$(date "+%Y-%m-%d_%H-%M-%S")
    variables_to_extract="name_client name_policy name_policy_full table_id table_mark custom_mark dscp_exclude dscp_proxy ipv4_proxy ipv4_exclude ipv6_proxy ipv6_exclude proxy_dns proxy_router start_attempts check_fd arm64_fd other_fd delay_fd ipv6_support extended_msg backup aghfix"
    source_main_backup=""
    source_start_backup=""

    if [ -f "$initd_file" ]; then
        source_main_backup="${backups_dir}/${current_datetime}_$(basename "$initd_file")"
        mv "$initd_file" "$source_main_backup"
    elif [ -f "$pre_initd_file" ]; then
        source_main_backup="${backups_dir}/${current_datetime}_$(basename "$pre_initd_file")"
        mv "$pre_initd_file" "$source_main_backup"
    elif [ -f "$old_initd_file" ] || [ -f "$old_start_file" ]; then
        if [ -f "$old_initd_file" ]; then
            source_main_backup="${backups_dir}/${current_datetime}_$(basename "$old_initd_file")"
            mv "$old_initd_file" "$source_main_backup"
        fi
        if [ -f "$old_start_file" ]; then
            source_start_backup="${backups_dir}/${current_datetime}_$(basename "$old_start_file")"
            mv "$old_start_file" "$source_start_backup"
        fi
    fi

    cp "$script_file" "$initd_file" || exit 1

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
                value=$(grep -m1 "^${var}=" "$source_main_backup") || continue
                escaped_value=$(printf '%s\n' "$value" | sed 's:[&#/]:\\&:g')
                position=$(grep -n "^${var}=" "$initd_file" | head -n 1 | cut -d: -f1)
                [ -n "$position" ] && sed -i "${position}s#.*#${escaped_value}#" "$initd_file"
            done
        fi
    fi

    chmod +x "$initd_file"
    if choice_backup_xkeen; then
        rm -f "$source_main_backup" "$source_start_backup"
    fi
    rm -f "$old_initd_file" "old_start_file" "$pre_initd_file"
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
    mkdir -p "$xkeen_cfg" || { echo "Ошибка: Не удалось создать директорию $xkeen_cfg"; exit 1; }
    if [ -f "/opt/etc/xkeen_exclude.lst" ] && [ ! -f "$file_ip_exclude" ]; then
        mv "/opt/etc/xkeen_exclude.lst" "$file_ip_exclude"
    elif [ ! -f "$file_ip_exclude" ]; then
        cat << EOF > "$file_ip_exclude"
#192.168.0.0/16
#2001:db8::/32

# Добавьте необходимые IP и подсети без комментария # для исключения их из проксирования
EOF
    fi

    if [ ! -f "$file_port_exclude" ]; then
        cat << EOF > "$file_port_exclude"
#

# Одновременно использовать порты проксирования и исключать порты нельзя
# Приоритет у портов проксирования
EOF
    fi

    if [ ! -f "$file_port_proxying" ]; then
        cat << EOF > "$file_port_proxying"
#80
#443
#596:599

# (Раскомментируйте/добавьте по образцу) единичные порты и диапазоны для проскирования
EOF
    fi
    if [ ! -f "$xkeen_config" ]; then
        cat << EOF > "$xkeen_config"
{
}
EOF
    fi
}
