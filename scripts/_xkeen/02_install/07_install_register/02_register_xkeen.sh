# Регистрация XKeen

# Функция для создания файла xkeen.control
register_xkeen_control() {
    write_opkg_control \
        "xkeen" \
        "$xkeen_current_version" \
        "jq, curl, coreutils-uname, coreutils-nohup, iptables, ipset, ip-full, conntrack" \
        "Skrill" \
        "xkeen" \
        "Skrill / jameszero" \
        "The platform that makes Xray work."
}

register_xkeen_list() {
    local list_tmp="${register_dir}/.xkeen.list.tmp.$$"
    [ -d "$register_dir" ] || return 1
    [ ! -e "$list_tmp" ] || return 1

    if [ -f "$register_dir/xkeen.list" ]; then
        cp -p "$register_dir/xkeen.list" "$list_tmp" || {
            rm -f "$list_tmp"
            return 1
        }
        : > "$list_tmp" || { rm -f "$list_tmp"; return 1; }
    else
        : > "$list_tmp" || return 1
    fi

    if ! find "$xkeen_dir" -mindepth 1 > "$list_tmp"; then
        rm -f "$list_tmp"
        return 1
    fi

    if ! printf '%s\n' \
        "$install_dir/xkeen" \
        "$xkeen_dir" \
        "$initd_file" \
        "$log_dir/xkeen-detached.log" >> "$list_tmp"; then
        rm -f "$list_tmp"
        return 1
    fi

    if ! mv -f "$list_tmp" "$register_dir/xkeen.list"; then
        rm -f "$list_tmp"
        return 1
    fi
}

register_xkeen_status() {
    write_opkg_status \
        "xkeen" \
        "$xkeen_current_version" \
        "jq, curl, coreutils-uname, coreutils-nohup, iptables, ipset, ip-full, conntrack"
}

fixed_register_packages() {
	awk 'BEGIN {RS=""; ORS="\n\n"} {gsub(/\n\n+/,"\n\n")}1' "$status_file" > "${register_dir}/tmp_status_file" && mv "${register_dir}/tmp_status_file" "$status_file"
}

create_initd_backup() {
    local source_file="$1"
    local backup_file="$2"
    local base_file="$2"
    local suffix=0

    [ -f "$source_file" ] || return 0
    mkdir -p "$backups_dir" || return 1

    if [ -e "$backup_file" ]; then
        backup_file="${base_file}.$$"
        while [ -e "$backup_file" ]; do
            suffix=$((suffix + 1))
            backup_file="${base_file}.$$.${suffix}"
        done
    fi

    cp "$source_file" "$backup_file" || {
        rm -f "$backup_file"
        return 1
    }
    [ -f "$backup_file" ] || return 1
    printf '%s\n' "$backup_file"
}

register_xkeen_initd() {
    old_initd_file="${initd_dir}/S24xray"
    pre_initd_file="${initd_dir}/S99xkeen"
    old_start_file="${initd_dir}/S99xkeenstart"
    script_file="${xinstall_dir}/07_install_register/04_register_init.sh" 
    current_datetime=$(date "+%Y-%m-%d_%H-%M-%S")
    variables_to_extract="name_client name_policy name_policy_full table_id table_mark allow_noisp dscp_enable dscp_force_proxy dscp_force_proxy_tag dscp_exclude dscp_proxy ipv4_proxy ipv4_exclude ipv6_proxy ipv6_exclude proxy_dns proxy_router nfqws_mark pbr_strict start_verbose start_attempts init_delay check_fd arm64_fd other_fd delay_fd ipv6_support extended_msg backup aghfix custom_mark"
    source_main_backup=""
    source_start_backup=""
    # Временный файл в $initd_dir: mv в конце — атомарный rename на одном
    # mountpoint, боевой $initd_file ни на миг не остаётся без содержимого
    initd_tmp_file="${initd_file}.tmp.$$"

    if [ -f "$initd_file" ]; then
        source_main_backup="${backups_dir}/${current_datetime}_$(basename "$initd_file")"
        source_main_backup=$(create_initd_backup "$initd_file" "$source_main_backup") || {
            echo "Ошибка: Не удалось сохранить предыдущий init-скрипт $initd_file" >&2
            exit 1
        }
    elif [ -f "$pre_initd_file" ]; then
        source_main_backup="${backups_dir}/${current_datetime}_$(basename "$pre_initd_file")"
        source_main_backup=$(create_initd_backup "$pre_initd_file" "$source_main_backup") || {
            echo "Ошибка: Не удалось сохранить предыдущий init-скрипт $pre_initd_file" >&2
            exit 1
        }
    elif [ -f "$old_initd_file" ] || [ -f "$old_start_file" ]; then
        if [ -f "$old_initd_file" ]; then
            source_main_backup="${backups_dir}/${current_datetime}_$(basename "$old_initd_file")"
            source_main_backup=$(create_initd_backup "$old_initd_file" "$source_main_backup") || {
                echo "Ошибка: Не удалось сохранить предыдущий init-скрипт $old_initd_file" >&2
                exit 1
            }
        fi
        if [ -f "$old_start_file" ]; then
            source_start_backup="${backups_dir}/${current_datetime}_$(basename "$old_start_file")"
            source_start_backup=$(create_initd_backup "$old_start_file" "$source_start_backup") || {
                echo "Ошибка: Не удалось сохранить предыдущий init-скрипт $old_start_file" >&2
                exit 1
            }
        fi
    fi

    cp "$script_file" "$initd_tmp_file" || { rm -f "$initd_tmp_file"; exit 1; }

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
             sed -i "s|^start_auto=.*|start_auto=$autostart_val|" "$initd_tmp_file"
        fi
        if [ -n "$start_delay_val" ]; then
             sed -i "s|^start_delay=.*|start_delay=$start_delay_val|" "$initd_tmp_file"
        fi

        if [ -n "$source_main_backup" ] && [ -f "$source_main_backup" ]; then
            for var in $variables_to_extract; do
                value=$(grep -m1 "^${var}=" "$source_main_backup") || continue
                escaped_value=$(printf '%s\n' "$value" | sed 's:[&#/]:\\&:g')
                position=$(grep -n "^${var}=" "$initd_tmp_file" | head -n 1 | cut -d: -f1)
                [ -n "$position" ] && sed -i "${position}s#.*#${escaped_value}#" "$initd_tmp_file"
            done
        fi
    fi

    chmod +x "$initd_tmp_file"
    mv -f "$initd_tmp_file" "$initd_file" || { rm -f "$initd_tmp_file"; exit 1; }

    if choice_backup_xkeen; then
        rm -f "$source_main_backup" "$source_start_backup"
    fi
    # Пропущенный $ ломал очистку легаси S99xkeenstart при апгрейде с 1.x
    rm -f "$old_initd_file" "$old_start_file" "$pre_initd_file"
}

# Создание конфигурации XKeen
create_xkeen_cfg() {
    previous_umask=$(umask)
    umask 077
    mkdir -p "$xkeen_cfg" || { echo "Ошибка: Не удалось создать директорию $xkeen_cfg"; exit 1; }
    chmod 700 "$xkeen_cfg" 2>/dev/null
    if [ -f "/opt/etc/xkeen_exclude.lst" ] && [ ! -f "$file_ip_exclude" ]; then
        mv "/opt/etc/xkeen_exclude.lst" "$file_ip_exclude"
    elif [ ! -f "$file_ip_exclude" ]; then
        cat << EOF > "$file_ip_exclude"
#77.88.8.8
#2a02:6b8::feed:0ff

# Укажите внешние IP-адреса и подсети (БЕЗ СИМВОЛА #) для исключения их из проксирования
# Не добавляйте в этот файл локальные адреса и подсети
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

# Добавьте по образцу (БЕЗ СИМВОЛА #) единичные порты и диапазоны для их проскирования
EOF
    fi
    if [ ! -f "$xkeen_config" ]; then
        cat << EOF > "$xkeen_config"
{
}
EOF
    fi
    chmod 600 "$xkeen_config" 2>/dev/null
    umask "$previous_umask"
}
