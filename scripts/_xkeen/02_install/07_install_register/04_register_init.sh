#!/bin/sh

# Информация о службе
# Краткое описание: Запуск / Остановка Xray
# Версия: 2.26

# Окружение
PATH="/opt/bin:/opt/sbin:/sbin:/bin:/usr/sbin:/usr/bin"

# Цвета
green="\033[32m"
red="\033[31m"
yellow="\033[33m"
reset="\033[0m"

# Имена
name_client="xray"
name_app="XKeen"
name_policy="xkeen"
name_profile="xkeen"
name_chain="xkeen"
name_prerouting_chain="$name_chain"
name_output_chain="${name_chain}_mask"

# Директории
directory_entware="/opt"
directory_os_lib="/lib"
directory_os_modules="$directory_os_lib/modules/$(uname -r)"
directory_user_lib="$directory_entware/lib"
directory_user_modules="$directory_user_lib/modules"
directory_binaries="$directory_entware/sbin"
directory_temporary="$directory_entware/tmp"
directory_configs="$directory_entware/etc"
directory_variable="$directory_entware/var"
directory_configs_app="$directory_configs/$name_client"
directory_app_routing="$directory_configs_app/dat"
directory_user_settings="$directory_configs_app/configs"
directory_logs="$directory_variable/log"
directory_logs_proxy="$directory_logs/$name_client"
directory_logs_xkeen="$directory_logs/xkeen"
directory_ndm="$directory_configs/ndm"
directory_nefilter="$directory_ndm/netfilter.d"

# Файлы
file_netfilter_hook="$directory_nefilter/proxy.sh"
client_xray="$directory_binaries/xray"
log_access="$directory_logs/$name_client/access.log"
log_error="$directory_logs/$name_client/error.log"

# URL
url_server="localhost:79"
url_policy="rci/show/ip/policy"
url_keenetic_port="rci/ip/http/ssl"
url_https_port="rci/ip/static"

# Настройки правил iptables
table_id="111"
table_mark="0x111"
table_redirect="nat"
table_tproxy="mangle"

ipv4_proxy="127.0.0.1"
ipv4_exclude="255.255.255.255/32 0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.168.0.0/16 198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4"
ipv6_proxy="::1"
ipv6_exclude="::1/128 0000::/8 0100::/64 0200::/7 2001:0002::/48 2001:0010::/28 2001:0db8::/32 2002::/16 3ffe::/16 fc00::/7 fd00::/8 fe80::/10 fec0::/10 ff00::/8 ::ffff:0:0/96 64:ff9b::/96 64:ff9b:1::/48 100::/64 2001::/23"

port_donor=""
port_exclude=""
port_dns="53"

ip4_supported=$(ip -4 addr show | grep -q "inet " && echo true || echo false)
ip6_supported=$(ip -6 addr show | grep -q "inet6 " && echo true || echo false)

iptables_supported=false
if [ $ip4_supported = "true" ]; then
    iptables_supported=$(command -v iptables >/dev/null 2>&1 && echo true)
fi

ip6tables_supported=false
if [ $ip6_supported = "true" ]; then
    ip6tables_supported=$(command -v ip6tables >/dev/null 2>&1 && echo true)
fi

# Настройки запуска
start_attempts=10
start_delay=0
start_auto="on"

# Контроль открытых файловых дескрипторов
check_fd="off"
arm64_fd=40000
other_fd=10000
delay_fd=60

# Функции журналирования
log_info_router() {
    logger -p notice -t "$name_app" "$1"
}

log_warning_router() {
    logger -p warning -t "$name_app" "$1"
}

log_error_router() {
    logger -p error -t "$name_app" "$1"
}

log_error_terminal() {
    echo
    echo -e "${red}Ошибка:${reset} $1" >&2
    exit 1
}

log_warning_terminal() {
    echo
    echo -e "${yellow}Предупреждение:${reset} $1" >&2
}

log_clean() {
    [ "$name_client" = "xray" ] && : > "$log_access" && : > "$log_error"
}

# Поиск конфигураций inbounds
file_inbounds() {
    find "$directory_user_settings" -name '*.json' -exec grep -lF '"inbounds": [' {} \; -quit
}
[ "$name_client" = "xray" ] && file_inbounds=$(file_inbounds)


# Поиск конфигураций DNS
file_dns() {
    find "$directory_user_settings" -name '*.json' -exec grep -lF '"dns": {' {} \; -quit
}
[ "$name_client" = "xray" ] && file_dns=$(file_dns)

create_user() {
    if ! id "xkeen" >/dev/null 2>&1; then
        adduser -D -H -u 11111 -g 11111 xkeen
        sed -i '/^xkeen:/c\xkeen:x:0:11111:::' /opt/etc/passwd
    fi
}

# Обработка модулей и портов
get_modules() {
    if [ "$mode_proxy" = "TProxy" ] || [ "$mode_proxy" = "Mixed_1" ]; then
        for module in xt_TPROXY.ko xt_socket.ko; do
            if [ ! -f "${directory_user_modules}/${module}" ] && [ ! -f "${directory_os_modules}/${module}" ] && ! lsmod | grep -q "${module%.ko}"; then
                proxy_stop
                log_error_terminal "
  Модуль ${module} не найден
  Невозможно запустить прокси в режиме ${mode_proxy} без него
  Установите компонент роутера '${yellow}Модули ядра подсистемы Netfilter${reset}'
  "
            fi
        done
    fi

    if [ -n "$port_donor" ] || [ -n "$port_exclude" ]; then
        module="xt_multiport.ko"
        if [ ! -f "${directory_user_modules}/${module}" ] && [ ! -f "${directory_os_modules}/${module}" ] && ! lsmod | grep -q "${module%.ko}"; then
            log_warning_terminal "
  Модуль multiport не найден
  Невозможно использовать указанные порты без него
  Установите компонент роутера '${yellow}Модули ядра подсистемы Netfilter${reset}'
  
  Прокси будет работать на всех портах
  "
            port_donor=""
            port_exclude=""
        else
            if [ -n "$port_donor" ] && [ $(echo "$port_donor" | tr ',' '\n' | wc -l) -gt 15 ]; then
                port_donor=$(echo "$port_donor" | tr ',' '\n' | head -n 15 | tr '\n' ',' | sed 's/,$//')
                log_warning_terminal "
  Количество проксируемых портов превышает лимит
  Будут оставлены первые 15: ${yellow}$port_donor${reset}
  "
            fi
            if [ -n "$port_exclude" ] && [ $(echo "$port_exclude" | tr ',' '\n' | wc -l) -gt 15 ]; then
                port_exclude=$(echo "$port_exclude" | tr ',' '\n' | head -n 15 | tr '\n' ',' | sed 's/,$//')
                log_warning_terminal "
  Количество исключаемых портов превышает лимит
  Будут оставлены первые 15: ${yellow}$port_exclude${reset}
  "
            fi
        fi
    fi

    if [ -n "$file_dns" ]; then
        module="xt_owner.ko"
        if [ ! -f "${directory_user_modules}/${module}" ] && [ ! -f "${directory_os_modules}/${module}" ] && ! lsmod | grep -q "${module%.ko}"; then
            file_dns=""
            log_warning_terminal "
  Модуль owner не найден
  Невозможно использовать DNS-сервер xray без него
  Установите компонент роутера '${yellow}Модули ядра подсистемы Netfilter${reset}'
  
  Прокси-клиент будет запущен с использованием DNS роутера
  "
        fi
    fi
}

# Получение порта Keenetic
get_keenetic_port() {
    result=$(curl -kfsS "${url_server}/${url_keenetic_port}" 2>/dev/null)
    keenetic_port=$(echo "$result" | jq -r '.port' 2>/dev/null)
    if [ "$keenetic_port" = "443" ]; then
        log_error_terminal "
  ${red}Порт 443 занят${reset} сервисами Keenetic
  
  Освободите его на странице 'Пользователи и доступ' веб-интерфейса роутера
  "
        proxy_stop
        exit 1
    fi
}

# Получение порта для Redirect
get_port_redirect() {
    for file in $(find "$directory_user_settings" -name '*.json'); do
        json=$(sed 's/\/\/.*$//' "$file" | tr -d '[:space:]')
        [ -n "$json" ] || continue
        inbounds=$(echo "$json" | jq -c '.inbounds[] | select(.protocol == "dokodemo-door" and .tag == "redirect")' 2>/dev/null)
        for inbound in $inbounds; do
            port=$(echo "$inbound" | jq -r '.port' 2>/dev/null)
            tproxy=$(echo "$inbound" | jq -r '.streamSettings.sockopt.tproxy // empty' 2>/dev/null)
            [ "$tproxy" != "tproxy" ] && echo "$port" && return
        done
    done
    echo "$port_redirect"
}

# Получение порта для TProxy
get_port_tproxy() {
    if [ "$name_client" = "mihomo" ]; then
        for file in $(find "$directory_configs_app" -name '*.yaml'); do
            port=$(yq eval '.tproxy-port' "$file" 2>/dev/null)
            if [ -z "$port" ]; then
                port=$(yq eval '.listeners[] | select(.name == "tproxy") | .port' "$file" 2>/dev/null)
            fi
            [ -n "$port" ] && echo "$port" && return
        done
    else
        for file in $(find "$directory_user_settings" -name '*.json'); do
            json=$(sed 's/\/\/.*$//' "$file" | tr -d '[:space:]')
            [ -n "$json" ] || continue
            inbounds=$(echo "$json" | jq -c '.inbounds[] | select(.protocol == "dokodemo-door" and .tag == "tproxy")' 2>/dev/null)
            for inbound in $inbounds; do
                port=$(echo "$inbound" | jq -r '.port' 2>/dev/null)
                tproxy=$(echo "$inbound" | jq -r '.streamSettings.sockopt.tproxy // empty' 2>/dev/null)
                [ "$tproxy" = "tproxy" ] && echo "$port" && return
            done
        done
    fi
    echo "$port_tproxy"
}

# Получение сети для Redirect
get_network_redirect() {
    for file in $(find "$directory_user_settings" -name '*.json'); do
        json=$(sed 's/\/\/.*$//' "$file" | tr -d '[:space:]')
        [ -n "$json" ] || continue
        inbounds=$(echo "$json" | jq -c '.inbounds[] | select(.protocol == "dokodemo-door" and .tag == "redirect")' 2>/dev/null)
        for inbound in $inbounds; do
            network=$(echo "$inbound" | jq -r '.settings.network' 2>/dev/null | tr -d '[:space:]' | tr ',' ' ')
            tproxy=$(echo "$inbound" | jq -r '.streamSettings.sockopt.tproxy // empty' 2>/dev/null)
            [ "$tproxy" != "tproxy" ] && echo "$network" && return
        done
    done
    echo "$network_redirect"
}

# Получение сети для TProxy
get_network_tproxy() {
    if [ "$name_client" = "mihomo" ]; then
        network_tproxy="tcp udp"
    else
        for file in $(find "$directory_user_settings" -name '*.json'); do
            json=$(sed 's/\/\/.*$//' "$file" | tr -d '[:space:]')
            [ -n "$json" ] || continue
            inbounds=$(echo "$json" | jq -c '.inbounds[] | select(.protocol == "dokodemo-door" and .tag == "tproxy")' 2>/dev/null)
            for inbound in $inbounds; do
                network=$(echo "$inbound" | jq -r '.settings.network' 2>/dev/null | tr -d '[:space:]' | tr ',' ' ')
                tproxy=$(echo "$inbound" | jq -r '.streamSettings.sockopt.tproxy // empty' 2>/dev/null)
                [ "$tproxy" = "tproxy" ] && echo "$network" && return
            done
        done
    fi
    echo "$network_tproxy"
}

# Получение исключенных портов
get_port_exclude() {
    result=$(curl -kfsS "${url_server}/${url_https_port}" 2>/dev/null)
    port_exclude_redirect=$(echo "$result" | jq -r '.[] | if has("to-port") then .["to-port"] else .port end' 2>/dev/null |
        grep -E -v '(^|,)80($|,)|(^|,)443($|,)' | tr '\n' ',' | sed 's/,$//')
    if [ -n "$port_exclude" ]; then
        port_exclude="$port_exclude,$port_exclude_redirect"
    else
        port_exclude="$port_exclude_redirect"
    fi
    port_exclude=$(echo "$port_exclude" | tr -dc '0-9,' | sed 's/,,*/,/g; s/^,//; s/,$//')
    echo "$port_exclude"
}

# Получение исключений IPv4
get_exclude_ip4() {
    [ "$iptables_supported" != "true" ] && return
    ipv4_eth=$(ip route get 77.88.8.8 2>/dev/null | awk '/src/ {print $NF}' ||
               ip route get 8.8.8.8 2>/dev/null | awk '/src/ {print $NF}' ||
               ip route get 1.1.1.1 2>/dev/null | awk '/src/ {print $NF}')
    [ -n "$ipv4_eth" ] && ipv4_eth="${ipv4_eth}/32 "
    echo "${ipv4_eth}${ipv4_exclude}" | tr -s ' '
}

# Получение исключений IPv6
get_exclude_ip6() {
    [ "$ip6tables_supported" != "true" ] && return
    ipv6_eth=$(ip -6 route get 2a02:6b8::feed:0ff 2>/dev/null | awk '/src/ {print $NF}' ||
               ip -6 route get 2001:4860:4860::8888 2>/dev/null | awk '/src/ {print $NF}' ||
               ip -6 route get 2606:4700:4700::1111 2>/dev/null | awk '/src/ {print $NF}')
    [ -n "$ipv6_eth" ] && ipv6_eth="${ipv6_eth}/128 "
    echo "${ipv6_eth}${ipv6_exclude}" | tr -s ' '
}

# Получение метки политики
get_policy_mark() {
    policy_mark=$(curl -kfsS "${url_server}/${url_policy}" 2>/dev/null |
        jq -r ".[] | select(.description | ascii_downcase == \"${name_policy}\") | .mark" 2>/dev/null)
    if ! proxy_status && [ -z "$policy_mark" ]; then
        if [ -z "${port_donor}" ]; then
            log_warning_terminal "
  Политика '${green}XKeen${reset}' не найдена в веб-интерфейсе роутера
  Не определены целевые порты для XKeen
  Прокси будет запущен для всего устройства на всех портах
  "
            echo ""
        else
            log_warning_terminal "
  Политика '${green}XKeen${reset}' не найдена в веб-интерфейсе роутера
  Определены целевые порты для XKeen
  Прокси будет запущен для всего устройства на портах ${port_donor}
  "
            echo ""
        fi
    else
        echo "0x${policy_mark}"
    fi
}

# Получение режима прокси-клиента
get_mode_proxy() {
    if [ -n "$port_redirect" ] && [ -n "$port_tproxy" ]; then
        mode_proxy="Mixed_1"
    elif [ -n "$port_tproxy" ]; then
        mode_proxy="TProxy"
    elif [ -n "$port_redirect" ]; then
        mode_proxy="Redirect"
    else
        mode_proxy="Other"
        log_info_router "$name_client запущен в обычном режиме. Направляйте соединения на $name_client вручную"
    fi
    [ "$mode_proxy" != "Other" ] && log_info_router "$name_client запущен в режиме $mode_proxy"
    echo "$mode_proxy"
}

# Настройка брандмауэра
configure_firewall() {
    : > "$file_netfilter_hook"
    cat > "$file_netfilter_hook" <<EOL
#!/bin/sh

name_client="$name_client"
name_profile="$name_profile"
mode_proxy="$mode_proxy"
network_redirect="$network_redirect"
network_tproxy="$network_tproxy"
networks="$networks"
name_prerouting_chain="$name_prerouting_chain"
name_output_chain="$name_output_chain"
port_redirect="$port_redirect"
port_tproxy="$port_tproxy"
port_donor="$port_donor"
port_exclude="$port_exclude"
port_dns="$port_dns"
multiport_option=""
policy_mark="$policy_mark"
table_redirect="$table_redirect"
table_tproxy="$table_tproxy"
table_mark="$table_mark"
table_id="$table_id"
file_dns="$file_dns"
directory_os_modules="$directory_os_modules"
directory_user_modules="$directory_user_modules"
directory_configs_app="$directory_configs_app"
directory_app_routing="$directory_app_routing"
directory_user_settings="$directory_user_settings"
iptables_supported=$iptables_supported
ip6tables_supported=$ip6tables_supported
arm64_fd=$arm64_fd
other_fd=$other_fd

# Перезапуск скрипта
restart_script() {
    exec /bin/sh "\$0" "\$@"
}

if pidof "\$name_client" >/dev/null; then
    # Загрузка модулей
    load_modules() {
        module="\$1"
        if [ -f "\${directory_user_modules}/\${module}" ]; then
            insmod "\${directory_user_modules}/\${module}" >/dev/null 2>&1 && return
        elif [ -f "\${directory_os_modules}/\${module}" ]; then
            insmod "\${directory_os_modules}/\${module}" >/dev/null 2>&1 && return
        elif ! lsmod | grep -q "\${module%.ko}"; then
            case "\${module}" in
                xt_owner.ko) file_dns="" ;;
                xt_multiport.ko) port_exclude=""; port_donor="" ;;
            esac
        fi
    }

    # Добавление правил iptables
    add_ipt_rule() {
        family="\$1"
        table="\$2"
        chain="\$3"
        shift 3
        [ "\$family" = "iptables" ] && [ "\$iptables_supported" = "false" ] && return
        [ "\$family" = "ip6tables" ] && [ "\$ip6tables_supported" = "false" ] && return
        if ! "\$family" -t "\$table" -nL \$name_prerouting_chain >/dev/null 2>&1; then
            "\$family" -t "\$table" -N \$name_prerouting_chain || exit 0
            add_exclude_rules \$name_prerouting_chain
            case "\$mode_proxy" in
                Mixed_1)
                    if [ "\$table" = "\$table_redirect" ]; then
                        "\$family" -w -t "\$table" -A \$name_prerouting_chain -p tcp -j REDIRECT --to-port "\$port_redirect" >/dev/null 2>&1
                    else
                        load_modules xt_TPROXY.ko
                        "\$family" -w -t "\$table" -I \$name_prerouting_chain -p udp -m socket --transparent -j MARK --set-mark "\$table_mark" >/dev/null 2>&1
                        "\$family" -w -t "\$table" -A \$name_prerouting_chain -p udp -j TPROXY --on-ip "\$proxy_ip" --on-port "\$port_tproxy" --tproxy-mark "\$table_mark" >/dev/null 2>&1
                    fi
                    ;;
                TProxy)
                    load_modules xt_TPROXY.ko
                    for net in \$network_tproxy; do
                        "\$family" -w -t "\$table" -I \$name_prerouting_chain -p "\$net" -m socket --transparent -j MARK --set-mark "\$table_mark" >/dev/null 2>&1
                        "\$family" -w -t "\$table" -A \$name_prerouting_chain -p "\$net" -j TPROXY --on-ip "\$proxy_ip" --on-port "\$port_tproxy" --tproxy-mark "\$table_mark" >/dev/null 2>&1
                    done
                    ;;
                Redirect)
                    for net in \$network_redirect; do
                        "\$family" -w -t "\$table" -A \$name_prerouting_chain -p "\$net" -j REDIRECT --to-port "\$port_redirect" >/dev/null 2>&1
                    done
                    ;;
                *) exit 0 ;;
            esac
        fi
        if [ "\$table" = "\$table_tproxy" ]; then
            if ! "\$family" -t "\$table" -nL \$name_output_chain >/dev/null 2>&1; then
                "\$family" -t "\$table" -N \$name_output_chain || exit 0
                add_exclude_rules \$name_output_chain
                for net in \$network_tproxy; do
                    "\$family" -w -t "\$table" -A \$name_output_chain -p "\$net" -j CONNMARK --set-mark "\$table_mark" >/dev/null 2>&1
                done
            fi
        fi
    }

    # Добавление правил-исключений
    add_exclude_rules() {
        chain="\$1"
        for exclude in \$exclude_list; do
            if [ "\$exclude" = "192.168.0.0/16" ] || [ "\$exclude" = "fd00::/8" ] && [ "\$chain" != "\$name_output_chain" ] && [ -n "\$file_dns" ]; then
                if [ -n "\${file_dns}" ]; then
                    if [ "\$table" = "mangle" ] && [ "\$mode_proxy" = "Mixed_1" ]; then
                        "\$family" -w -t "\$table" -A "\$chain" -d "\$exclude" -p tcp --dport "\$port_dns" -j RETURN >/dev/null 2>&1
                        "\$family" -w -t "\$table" -A "\$chain" -d "\$exclude" -p udp ! --dport "\$port_dns" -j RETURN >/dev/null 2>&1
                    elif [ "\$table" = "nat" ] && [ "\$mode_proxy" = "Mixed_1" ]; then
                        "\$family" -w -t "\$table" -A "\$chain" -d "\$exclude" -p tcp ! --dport "\$port_dns" -j RETURN >/dev/null 2>&1
                        "\$family" -w -t "\$table" -A "\$chain" -d "\$exclude" -p udp --dport "\$port_dns" -j RETURN >/dev/null 2>&1
                    elif [ "\$table" = "mangle" ] && [ "\$mode_proxy" = "TProxy" ]; then
                        "\$family" -w -t "\$table" -A "\$chain" -d "\$exclude" -p tcp ! --dport "\$port_dns" -j RETURN >/dev/null 2>&1
                        "\$family" -w -t "\$table" -A "\$chain" -d "\$exclude" -p udp ! --dport "\$port_dns" -j RETURN >/dev/null 2>&1
                    fi
                fi
            else
                "\$family" -w -t "\$table" -A "\$chain" -d "\$exclude" -j RETURN >/dev/null 2>&1
            fi
        done
    }

    # Настройка таблицы маршрутов
    configure_route() {
        ip_version="\$1"
        if ! ip -"\$ip_version" rule show | grep -q "fwmark \$table_mark lookup \$table_id"; then
            if [ -n "\$policy_mark" ]; then
                policy_table=\$(ip rule show | awk -v policy="\$policy_mark" '\$0 ~ policy && /lookup/ && !/blackhole/{print \$NF}')
            fi
            ip -"\$ip_version" rule add fwmark "\$table_mark" lookup "\$table_id" >/dev/null 2>&1
            ip -"\$ip_version" route add local default dev lo table "\$table_id" >/dev/null 2>&1
            if [ -n "\$policy_table" ]; then
                ip -"\$ip_version" route show table "\$policy_table" | grep -Ev '^default' |
                while read route; do
                    matching_main_route=\$(ip -"\$ip_version" route show table main | grep -F "\$route")
                    ip -"\$ip_version" route add table "\$table_id" \$matching_main_route >/dev/null 2>&1
                done
            else
                ip -"\$ip_version" route show table main | grep -Ev '^default' |
                while read route; do
                    ip -"\$ip_version" route add table "\$table_id" \$route >/dev/null 2>&1
                done
            fi
        fi
    }

    # Добавление цепочек PREROUTING
    add_prerouting() {
        family="\$1"
        table="\$2"
        for net in \$networks; do
            if [ "\$mode_proxy" = "Mixed_1" ]; then
                case "\$net" in
                    tcp)
                        table="nat"
                        if [ "\$family" = "iptables" ] && [ "\$iptables_supported" = "true" ] &&
                           ! iptables -t "\$table" -C PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -p tcp \$multiport_option -j \$name_prerouting_chain >/dev/null 2>&1; then
                            iptables -t "\$table" -A PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -p tcp \$multiport_option -j \$name_prerouting_chain >/dev/null 2>&1
                        fi
                        if [ "\$family" = "ip6tables" ] && [ "\$ip6tables_supported" = "true" ] &&
                           ! ip6tables -t "\$table" -C PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -p tcp \$multiport_option -j \$name_prerouting_chain >/dev/null 2>&1; then
                            ip6tables -t "\$table" -A PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -p tcp \$multiport_option -j \$name_prerouting_chain >/dev/null 2>&1
                        fi
                        ;;
                    udp)
                        table="mangle"
                        if [ "\$family" = "iptables" ] && [ "\$iptables_supported" = "true" ] &&
                           ! iptables -t "\$table" -C PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -p udp \$multiport_option -j \$name_prerouting_chain >/dev/null 2>&1; then
                            iptables -t "\$table" -A PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -p udp \$multiport_option -j \$name_prerouting_chain >/dev/null 2>&1
                        fi
                        if [ "\$family" = "ip6tables" ] && [ "\$ip6tables_supported" = "true" ] &&
                           ! ip6tables -t "\$table" -C PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -p udp \$multiport_option -j \$name_prerouting_chain >/dev/null 2>&1; then
                            ip6tables -t "\$table" -A PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -p udp \$multiport_option -j \$name_prerouting_chain >/dev/null 2>&1
                        fi
                        ;;
                    *) exit 0 ;;
                esac
            else
                if [ -n "\$multiport_option" ]; then
                        if [ "\$family" = "iptables" ] && [ "\$iptables_supported" = "true" ] &&
                           ! iptables -t "\$table" -C PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -p \$net \$multiport_option -j \$name_prerouting_chain >/dev/null 2>&1; then
                            iptables -t "\$table" -A PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -p \$net \$multiport_option -j \$name_prerouting_chain >/dev/null 2>&1
                        fi
                        if [ "\$family" = "ip6tables" ] && [ "\$ip6tables_supported" = "true" ] &&
                           ! ip6tables -t "\$table" -C PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -p \$net \$multiport_option -j \$name_prerouting_chain >/dev/null 2>&1; then
                            ip6tables -t "\$table" -A PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -p \$net \$multiport_option -j \$name_prerouting_chain >/dev/null 2>&1
                        fi
                else
                        if [ "\$family" = "iptables" ] && [ "\$iptables_supported" = "true" ] &&
                           ! iptables -t "\$table" -C PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -j \$name_prerouting_chain >/dev/null 2>&1; then
                            iptables -t "\$table" -A PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -j \$name_prerouting_chain >/dev/null 2>&1
                        fi
                        if [ "\$family" = "ip6tables" ] && [ "\$ip6tables_supported" = "true" ] &&
                           ! ip6tables -t "\$table" -C PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -j \$name_prerouting_chain >/dev/null 2>&1; then
                            ip6tables -t "\$table" -A PREROUTING \$connmark_option -m conntrack ! --ctstate INVALID -j \$name_prerouting_chain >/dev/null 2>&1
                        fi
                fi
            fi
        done
    }

    # Добавление цепочек OUTPUT
    add_output() {
        family="\$1"
        table="\$2"
        if [ "\$mode_proxy" = "TProxy" ]; then
                if [ "\$family" = "iptables" ] && [ "\$iptables_supported" = "true" ] &&
                   ! iptables -t "\$table" -C OUTPUT -m owner ! --uid-owner \$name_profile -m conntrack ! --ctstate INVALID ! -p icmp -j \$name_output_chain >/dev/null 2>&1; then
                    iptables -t "\$table" -A OUTPUT -m owner ! --uid-owner \$name_profile -m conntrack ! --ctstate INVALID ! -p icmp -j \$name_output_chain >/dev/null 2>&1
                fi
                if [ "\$family" = "ip6tables" ] && [ "\$ip6tables_supported" = "true" ] &&
                   ! ip6tables -t "\$table" -C OUTPUT -m owner ! --uid-owner \$name_profile -m conntrack ! --ctstate INVALID ! -p icmp -j \$name_output_chain >/dev/null 2>&1; then
                    ip6tables -t "\$table" -A OUTPUT -m owner ! --uid-owner \$name_profile -m conntrack ! --ctstate INVALID ! -p icmp -j \$name_output_chain >/dev/null 2>&1
                fi
        fi
        if [ "\$mode_proxy" = "Mixed_1" ]; then
                if [ "\$family" = "iptables" ] && [ "\$iptables_supported" = "true" ] &&
                   ! iptables -t "\$table" -C OUTPUT -m owner ! --uid-owner \$name_profile -m conntrack ! --ctstate INVALID -p udp -j \$name_output_chain >/dev/null 2>&1; then
                    iptables -t "\$table" -A OUTPUT -m owner ! --uid-owner \$name_profile -m conntrack ! --ctstate INVALID -p udp -j \$name_output_chain >/dev/null 2>&1
                fi
                if [ "\$family" = "ip6tables" ] && [ "\$ip6tables_supported" = "true" ] &&
                   ! ip6tables -t "\$table" -C OUTPUT -m owner ! --uid-owner \$name_profile -m conntrack ! --ctstate INVALID -p udp -j \$name_output_chain >/dev/null 2>&1; then
                    ip6tables -t "\$table" -A OUTPUT -m owner ! --uid-owner \$name_profile -m conntrack ! --ctstate INVALID -p udp -j \$name_output_chain >/dev/null 2>&1
                fi
        fi
    }

    [ -n "\$policy_mark" ] && connmark_option="-m connmark --mark \$policy_mark"
    if [ -n "\$port_donor" ] || [ -n "\$port_exclude" ]; then
        load_modules xt_multiport.ko
        [ -n "\$file_dns" ] && [ -n "\$port_donor" ] && port_donor="\$port_dns,\$port_donor"
        [ -n "\$port_donor" ] && multiport_option="-m multiport --dports \$port_donor"
        [ -n "\$port_exclude" ] && [ -z "\$port_donor" ] && multiport_option="-m multiport ! --dports \$port_exclude"
    fi

    for family in iptables ip6tables; do
        if [ "\$family" = "ip6tables" ]; then
            exclude_list="$(get_exclude_ip6)"
            proxy_ip="$ipv6_proxy"
            configure_route 6
        else
            exclude_list="$(get_exclude_ip4)"
            proxy_ip="$ipv4_proxy"
            configure_route 4
        fi
        if [ -n "\$port_redirect" ] && [ -n "\$port_tproxy" ]; then
            for table in "\$table_tproxy" "\$table_redirect"; do
                add_ipt_rule "\$family" "\$table" "\$name_prerouting_chain"
                add_prerouting "\$family" "\$table"
            done
        elif [ -z "\$port_redirect" ] && [ -n "\$port_tproxy" ]; then
            table="\$table_tproxy"
            add_ipt_rule "\$family" "\$table" "\$name_prerouting_chain"
            add_prerouting "\$family" "\$table"
        elif [ -n "\$port_redirect" ] && [ -z "\$port_tproxy" ]; then
            table="\$table_redirect"
            add_ipt_rule "\$family" "\$table" "\$name_prerouting_chain"
            add_prerouting "\$family" "\$table"
        fi
        if [ "\$mode_proxy" != "Redirect" ]; then
            load_modules xt_socket.ko
            load_modules xt_owner.ko
            add_ipt_rule "\$family" "\$table_tproxy" "\$name_output_chain"
            add_output "\$family" "\$table_tproxy"
        fi
    done
else
    . "/opt/sbin/.xkeen/01_info/03_info_cpu.sh"
    status_file="/opt/lib/opkg/status"
    info_cpu
    case "\$name_client" in
        xray)
            export XRAY_LOCATION_ASSET="\$directory_app_routing"
            export XRAY_LOCATION_CONFDIR="\$directory_user_settings"
            if [ "\$architecture" = "arm64-v8a" ]; then
                ulimit -SHn "\$arm64_fd" && su -c "\$name_client run" "\$name_profile" >/dev/null 2>&1 &
            else
                ulimit -SHn "\$other_fd" && su -c "\$name_client run" "\$name_profile" >/dev/null 2>&1 &
            fi
        ;;
        mihomo)
            if [ "\$architecture" = "arm64-v8a" ]; then
                ulimit -SHn "\$arm64_fd" && su -c "\$name_client -d \$directory_configs_app" "\$name_profile" >/dev/null 2>&1 &
            else
                ulimit -SHn "\$other_fd" && su -c "\$name_client -d \$directory_configs_app" "\$name_profile" >/dev/null 2>&1 &
            fi
        ;;
    esac
    sleep 5
    restart_script "\$@"
fi
EOL

    chmod +x "$file_netfilter_hook"
    sh "$file_netfilter_hook"
}

# Удаление правил Iptables
clean_firewall() {
    [ -f "$file_netfilter_hook" ] && : > "$file_netfilter_hook"

    clean_run() {
        family="$1"
        table="$2"
        name_chain="$3"
            if "$family" -t "$table" -nL "$name_chain" >/dev/null 2>&1; then
                "$family" -t "$table" -F "$name_chain" >/dev/null 2>&1
                while "$family" -w -t "$table" -nL PREROUTING | grep -q "$name_chain"; do
                    rule_number=$("$family" -w -t "$table" -nL PREROUTING --line-numbers | grep -v "Chain" | grep -m 1 "$name_chain" | awk '{print $1}')
                    "$family" -w -t "$table" -D PREROUTING "$rule_number" >/dev/null 2>&1
                done
                "$family" -w -t "$table" -X "$name_chain" >/dev/null 2>&1
            fi
            if "$family" -t "$table" -nL "$name_chain" >/dev/null 2>&1; then
                "$family" -t "$table" -F "$name_chain" >/dev/null 2>&1
                while "$family" -w -t "$table" -nL OUTPUT | grep -q "$name_chain"; do
                    rule_number=$("$family" -w -t "$table" -nL OUTPUT --line-numbers | grep -v "Chain" | grep -m 1 "$name_chain" | awk '{print $1}')
                    "$family" -w -t "$table" -D OUTPUT "$rule_number" >/dev/null 2>&1
                done
                "$family" -w -t "$table" -X "$name_chain" >/dev/null 2>&1
            fi
    }

    for family in iptables ip6tables; do
        for chain in nat mangle; do
            clean_run "$family" "$chain" "$name_prerouting_chain"
            clean_run "$family" "$chain" "$name_output_chain"
        done
    done

    if command -v ip >/dev/null 2>&1; then
        for family in 4 6; do
            if ip -"$family" rule show | grep -q "fwmark $table_mark lookup $table_id"; then
                ip -"$family" rule del fwmark "$table_mark" lookup "$table_id" >/dev/null 2>&1
                ip -"$family" route flush table "$table_id" >/dev/null 2>&1
            fi
        done
    fi
}

# Проверка статуса прокси-клиента
proxy_status() {
    pidof "$name_client" >/dev/null
}

# Мониторинг файловых дескрипторов
monitor_fd() {
    if ! opkg list-installed | grep -q "^coreutils-nohup"; then
        opkg update && opkg install coreutils-nohup
    fi
    while true; do
        client_pid=$(pidof "$name_client")
        if [ -n "$client_pid" ] && [ -d "/proc/$client_pid/fd" ]; then
            limit=$(awk '/Max open files/ {print $4}' "/proc/$client_pid/limits")
            current=$(ls -1 /proc/$client_pid/fd 2>/dev/null | wc -l)
            if [ "$limit" -gt 0 ] && [ "$current" -gt $((limit * 90 / 100)) ]; then
                log_warning_router "$name_client открыл $current из $limit файловых дескрипторов, инициирован перезапуск"
                fd_out=true
                proxy_stop
                proxy_start "on"
            fi
        fi
        sleep "$delay_fd"
    done
}

# Запуск прокси-клиента
proxy_start() {
    start_manual="$1"
    if [ "$start_manual" = "on" ] || [ "$start_auto" = "on" ]; then
        log_info_router "Инициирован запуск прокси-клиента"
        log_clean
        if [ "$name_client" = "xray" ]; then
            port_redirect=$(get_port_redirect)
            network_redirect=$(get_network_redirect)
        fi
        port_tproxy=$(get_port_tproxy)
        network_tproxy=$(get_network_tproxy)
        mode_proxy=$(get_mode_proxy)
        if [ "$mode_proxy" != "Other" ]; then
            policy_mark=$(get_policy_mark)
            networks=$(echo "$network_redirect $network_tproxy" | tr ',' ' ' | tr -s ' ' | sort -u | tr '\n' ' ' | sed 's/^ //; s/ $//')
            if [ -n "$policy_mark" ] && [ -z "$port_donor" ]; then
                port_exclude=$(get_port_exclude)
            fi
            if ! proxy_status && { [ -n "$port_donor" ] || [ -n "$port_exclude" ] || [ "$mode_proxy" = "TProxy" ] || [ "$mode_proxy" = "Mixed_1" ]; }; then
                get_modules
            fi
            if [ "$mode_proxy" = "TProxy" ] || [ "$mode_proxy" = "Mixed_1" ]; then
                get_keenetic_port
            fi
        fi
        if proxy_status; then
            echo -e "  Прокси-клиент уже ${green}запущен${reset}"
            log_error_terminal "Не удалось запустить $name_client, так как он уже запущен"
        else
            delay_increment=1
            current_delay=$start_delay
            attempt=1
            create_user
            . "/opt/sbin/.xkeen/01_info/03_info_cpu.sh"
            status_file="/opt/lib/opkg/status"
            info_cpu
            while [ "$attempt" -le "$start_attempts" ]; do
                case "$name_client" in
                    xray)
                        export XRAY_LOCATION_ASSET="$directory_app_routing"
                        export XRAY_LOCATION_CONFDIR="$directory_user_settings"
                        if [ "$architecture" = "arm64-v8a" ]; then
                            if [ -n "$fd_out" ]; then
                                ulimit -SHn "$arm64_fd" && nohup su -c "$name_client run" "$name_profile" >/dev/null 2>&1 &
                                unset fd_out
                            else
                                ulimit -SHn "$arm64_fd" && su -c "$name_client run" "$name_profile" &
                            fi
                        else
                            if [ -n "$fd_out" ]; then
                                ulimit -SHn "$other_fd" && nohup su -c "$name_client run" "$name_profile" >/dev/null 2>&1 &
                                unset fd_out
                            else
                                ulimit -SHn "$other_fd" && su -c "$name_client run" "$name_profile" &
                            fi
                        fi
                    ;;
                    mihomo)
                        if [ "$architecture" = "arm64-v8a" ]; then
                            if [ -n "$fd_out" ]; then
                                ulimit -SHn "$arm64_fd" && nohup su -c "$name_client -d $directory_configs_app" "$name_profile" >/dev/null 2>&1 &
                                unset fd_out
                            else
                                ulimit -SHn "$arm64_fd" && su -c "$name_client -d $directory_configs_app" "$name_profile" &
                            fi
                        else
                            if [ -n "$fd_out" ]; then
                                ulimit -SHn "$other_fd" && nohup su -c "$name_client -d $directory_configs_app" "$name_profile" >/dev/null 2>&1 &
                                unset fd_out
                            else
                                ulimit -SHn "$other_fd" && su -c "$name_client -d $directory_configs_app" "$name_profile" &
                            fi
                        fi
                        ;;
                    *) "$name_client" run -C "$directory_user_settings" & ;;
                esac
                sleep "$current_delay"
                if proxy_status; then
                    [ "$mode_proxy" != "Other" ] && configure_firewall
                    echo -e "  Прокси-клиент ${green}запущен${reset}"
                    log_info_router "Прокси-клиент успешно запущен"
                    if [ "$check_fd" = "on" ] && [ -f "/tmp/start_fd" ] && [ ! -f "/tmp/observer_fd" ]; then
                        touch "/tmp/observer_fd"
                        monitor_fd &
                    fi
                    return 0
                fi
                current_delay=$((current_delay + delay_increment))
                attempt=$((attempt + 1))
            done
            echo -e "  ${red}Не удалось запустить${reset} прокси-клиент"
            log_error_terminal "Не удалось запустить прокси-клиент"
        fi
    else
        clean_firewall
    fi
}

# Остановка прокси-клиента
proxy_stop() {
    if ! proxy_status; then
        echo -e "  Прокси-клиент ${red}не запущен${reset}"
    else
        log_info_router "Инициирована остановка прокси-клиента"
        delay_increment=1
        current_delay=$start_delay
        attempt=1
        while [ "$attempt" -le "$start_attempts" ]; do
            clean_firewall
            killall -q -9 "$name_client"
            sleep "$current_delay"
            if ! proxy_status; then
                echo -e "  Прокси-клиент ${yellow}остановлен${reset}"
                log_info_router "Прокси-клиент успешно остановлен"
                return 0
            fi
            current_delay=$((current_delay + delay_increment))
            attempt=$((attempt + 1))
        done
        echo -e "  Прокси-клиент ${red}не удалось остановить${reset}"
        log_error_terminal "Не удалось остановить прокси-клиент"
    fi
}

# Менеджер команд
case "$1" in
    start) proxy_start "$2" ;;
    stop) proxy_stop ;;
    status)
        if proxy_status; then
            echo -e "  Прокси-клиент ${green}запущен${reset}"
        else
            echo -e "  Прокси-клиент ${red}не запущен${reset}"
        fi
        ;;
    restart) proxy_stop; proxy_start "$2" ;;
    *) echo -e "  Команды: ${green}start${reset} | ${red}stop${reset} | ${yellow}restart${reset} | status" ;;
esac

exit 0