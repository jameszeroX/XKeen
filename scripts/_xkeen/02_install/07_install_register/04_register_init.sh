#!/bin/sh

# Информация о службе: Запуск / Остановка XKeen
# Версия: 2.29

# Окружение
PATH="/opt/bin:/opt/sbin:/sbin:/bin:/usr/sbin:/usr/bin"

# Цвета
green="\033[92m"
red="\033[91m"
yellow="\033[93m"
light_blue="\033[96m"
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
directory_os_modules="/lib/modules/$(uname -r)"
directory_user_modules="/opt/lib/modules"
directory_configs_app="/opt/etc/$name_client"
directory_xray_config="$directory_configs_app/configs"
directory_xray_asset="$directory_configs_app/dat"
directory_logs="/opt/var/log"
xkeen_cfg="/opt/etc/xkeen"

# Файлы
file_netfilter_hook="/opt/etc/ndm/netfilter.d/proxy.sh"
log_access="$directory_logs/$name_client/access.log"
log_error="$directory_logs/$name_client/error.log"
mihomo_config="$directory_configs_app/config.yaml"
file_port_proxying="$xkeen_cfg/port_proxying.lst"
file_port_exclude="$xkeen_cfg/port_exclude.lst"
file_ip_exclude="$xkeen_cfg/ip_exclude.lst"
xkeen_config="$xkeen_cfg/xkeen.json"

# URL
url_server="localhost:79"
url_policy="rci/show/ip/policy"
url_keenetic_port="rci/ip/http"
url_redirect_port="rci/ip/static"

# Настройки правил iptables
table_id="111"
table_mark="0x111"
table_redirect="nat"
table_tproxy="mangle"

ipv4_proxy="127.0.0.1"
ipv4_exclude="0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 255.255.255.255"
ipv6_proxy="::1"
ipv6_exclude="::/128 ::1/128 64:ff9b::/96 2001::/32 2002::/16 fd00::/8 ff00::/8 fe80::/10"

# Перехват DNS в прокси
proxy_dns="off"

# Настройки запуска
start_attempts=10
start_auto="on"
start_delay=30

# Контроль файловых дескрипторов
check_fd="off"
arm64_fd=40000
other_fd=10000
delay_fd=60

# Резервное копирование XKeen при обновлении
backup="on"

# Поддержка IPv6
ipv6_support="on"

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
    echo -e "${red}Ошибка${reset}: $1" >&2
    exit 1
}

log_warning_terminal() {
    echo
    echo -e "${yellow}Предупреждение${reset}: $1" >&2
}

log_clean() {
    [ "$name_client" = "xray" ] && : > "$log_access" && : > "$log_error"
}

# Получение портов Keenetic
get_keenetic_port() {
    ports=""

    ports=$(curl -kfsS "${url_server}/${url_keenetic_port}" 2>/dev/null \
        | jq -r '.port, (.ssl.port // empty)' 2>/dev/null)

    for p in $ports; do
        [ "$p" = "443" ] && return 1
    done

    if [ -z "$ports" ]; then
        ndmc -c 'ip http port 8080' >/dev/null 2>&1
        ndmc -c 'ip http port 80' >/dev/null 2>&1
        ndmc -c 'system configuration save' >/dev/null 2>&1

        sleep 2

        ports=$(curl -kfsS "${url_server}/${url_keenetic_port}" 2>/dev/null \
            | jq -r '.port, (.ssl.port // empty)' 2>/dev/null)
    fi

    [ -n "$ports" ] || return 1

    echo "$ports"
    return 0
}

wait_for_webui() {
    ports="$(get_keenetic_port | grep -E '^[0-9]+$')" || return 1
    [ -n "$ports" ] || return 1

    i=0
    max_wait=10

    while [ "$i" -lt "$max_wait" ]; do
        for p in $ports; do
            if netstat -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(:|\\.)$p$"; then
                return 0
            fi
        done
        sleep 1
        i=$((i + 1))
    done

    return 1
}

apply_ipv6_state() {
    ipv6_disabled=
    ipv6_disabled=$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null || echo "0")

    [ "$ipv6_disabled" -eq 1 ] && return 0

    [ "$ipv6_support" != "off" ] && return 0

    ip -6 addr show 2>/dev/null | grep -q "inet6 " || return 0

    if ! wait_for_webui; then
        log_error_router "Веб-интерфейс роутера недоступен"
        return 1
    fi

    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
    if [ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)" -eq 1 ] &&
       [ "$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null)" -eq 1 ]; then
        log_info_router "Отключение IPv6 выполнено"
        return 0
    fi
}
apply_ipv6_state

ip4_supported=$(ip -4 addr show 2>/dev/null | grep -q "inet " && echo true || echo false)
ip6_supported=$(ip -6 addr show 2>/dev/null | grep -q "inet6 " && echo true || echo false)

iptables_supported=$([ "$ip4_supported" = "true" ] && command -v iptables >/dev/null 2>&1 && echo true || echo false)
ip6tables_supported=$([ "$ip6_supported" = "true" ] && command -v ip6tables >/dev/null 2>&1 && echo true || echo false)

# Функция валидации xkeen.json
validate_xkeen_json() {
    if [ ! -f "$xkeen_config" ]; then
        return 0
    fi
    if ! jq empty "$xkeen_config" 2>/dev/null; then
        error_output=$(yq '.' "$xkeen_config" 2>&1)
            log_error_terminal "
  Валидация JSON: файл ${light_blue}xkeen.json${reset} содержит синтаксические ошибки
  Запуск прокси невозможен
"
        exit 1
    fi

    if ! yq -e '.xkeen.policy[]? | .name' "$xkeen_config" >/dev/null 2>&1; then
        if yq -e '.xkeen' "$xkeen_config" >/dev/null 2>&1; then
            log_error_terminal "
  Файл ${light_blue}xkeen.json${reset} имеет неверную структуру
  Запуск прокси невозможен
"
        exit 1
        fi
    fi

    return 0
}

get_user_ipv4_excludes() {
    if [ -f "$file_ip_exclude" ]; then
        echo -n " "
        sed 's/\r$//' "$file_ip_exclude" | \
        sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
        grep -v '^#' | \
        grep -v '^$' | \
        grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?' | \
        tr '\n' ' ' | \
        sed 's/  */ /g; s/^ //; s/ $//'
    else
        echo ""
    fi
}

get_user_ipv6_excludes() {
    if [ -f "$file_ip_exclude" ]; then
        echo -n " "
        sed 's/\r$//' "$file_ip_exclude" | \
        sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
        grep -v '^#' | \
        grep -v '^$' | \
        grep -Eo '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}(/[0-9]{1,3})?' | \
        tr '\n' ' ' | \
        sed 's/  */ /g; s/^ //; s/ $//'
    else
        echo ""
    fi
}

read_ports_from_file() {
    file="$1"

    [ -f "$file" ] || return

    sed 's/\r$//' "$file" | \
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
    grep -v '^#' | \
    grep -v '^$' | \
    tr '\n' ',' | \
    sed 's/,$//'
}

# Функция обработки, валидации и нормализации списка портов
validate_and_clean_ports() {
    input_ports="$1"

    echo "$input_ports" | tr ',' '\n' | awk '
        function is_valid(p) {
            return p ~ /^[0-9]+$/ && p > 0 && p <= 65535
        }
        {
            gsub(/[[:space:]]/, "", $0)
            if ($0 == "") next

            n = split($0, a, ":")

            if (n == 1) {
                if (is_valid(a[1])) {
                    print a[1]
                }
            }

            else if (n == 2) {
                if (is_valid(a[1]) && is_valid(a[2])) {
                    start = a[1]
                    end   = a[2]

                    if (start > end) {
                        tmp = start
                        start = end
                        end = tmp
                    }

                    if (start < end) {
                        print start ":" end
                    }
                }
            }
        }
    ' | sort -n -u | tr '\n' ',' | sed 's/,$//'
}

# Функция обработки пользовательских портов
process_user_ports() {
    user_proxy_ports=""
    user_exclude_ports=""

    if [ -f "$file_port_proxying" ]; then
        user_proxy_ports=$(
            sed 's/\r$//' "$file_port_proxying" | \
            sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
            grep -v '^#' | \
            grep -v '^$' | \
            sed 's/-/:/g' | \
            grep -E '^[0-9]+(:[0-9]+)?$' | \
            tr '\n' ',' | \
            sed 's/,$//'
        )
    fi

    if [ -f "$file_port_exclude" ]; then
        user_exclude_ports=$(
            sed 's/\r$//' "$file_port_exclude" | \
            sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | \
            grep -v '^#' | \
            grep -v '^$' | \
            sed 's/-/:/g' | \
            grep -E '^[0-9]+(:[0-9]+)?$' | \
            tr '\n' ',' | \
            sed 's/,$//'
        )
    fi

    port_donor=$(validate_and_clean_ports "$(read_ports_from_file "$file_port_proxying")")
    port_exclude=$(validate_and_clean_ports "$(read_ports_from_file "$file_port_exclude")")

    if [ -n "$port_donor" ]; then
        if echo "$port_donor" | grep -qv "\(^\|,\)80\(,\|$\)"; then
            port_donor="80,${port_donor}"
        fi
        if echo "$port_donor" | grep -qv "\(^\|,\)443\(,\|$\)"; then
            port_donor="443,${port_donor}"
        fi
    fi

    if [ -n "$port_donor" ] && [ -n "$port_exclude" ]; then
        log_error_terminal "
  Заданы и порты проксирования, и порты исключения
  Используйте, что-то одно
"
        exit 1
    fi
}

# Проверка статуса прокси-клиента
proxy_status() { pidof $name_client >/dev/null; }

# Поиск конфигурации inbounds
[ "$name_client" = "xray" ] && file_inbounds=$(find "$directory_xray_config" -maxdepth 1 -name '*.json' -exec grep -lF '"inbounds":' {} \; -quit 2>/dev/null || true)

# Поиск конфигураций DNS
file_dns_xray() {
    if [ "$proxy_dns" = "on" ]; then
        for file in "$directory_xray_config"/*.json; do
            [ -f "$file" ] || continue
            if grep -q '"dns":' "$file" && grep -q '"servers":' "$file"; then
                echo "$file"
                return 0
            fi
        done
        return 1
    fi
}

file_dns_mihomo() {
    if [ "$proxy_dns" = "on" ]; then
        [ -f "$mihomo_config" ] || return 1
        if yq -e '.dns.enable == true' "$mihomo_config" >/dev/null 2>&1; then
            echo "$mihomo_config"
            return 0
        fi
        return 1
    fi
}

[ "$name_client" = "xray" ] && file_dns=$(file_dns_xray)
[ "$name_client" = "mihomo" ] && file_dns=$(file_dns_mihomo)

create_user() {
    if ! id "xkeen" >/dev/null 2>&1; then
        adduser -D -H -u 11111 -g 11111 xkeen
        sed -i '/^xkeen:/c\xkeen:x:0:11111:::' /opt/etc/passwd
    fi
}

# Загрузка модулей
load_modules() {
    module="$1"
    if [ -f "${directory_os_modules}/${module}" ]; then
        insmod "${directory_os_modules}/${module}" >/dev/null 2>&1 && return
    elif [ -f "${directory_user_modules}/${module}" ]; then
        insmod "${directory_user_modules}/${module}" >/dev/null 2>&1 && return
    fi
}

load_modules xt_TPROXY.ko
load_modules xt_socket.ko
load_modules xt_multiport.ko

# Обработка модулей и портов
get_modules() {
    if [ "$mode_proxy" = "TProxy" ] || [ "$mode_proxy" = "Mixed" ]; then
        for module in xt_TPROXY.ko xt_socket.ko; do
            if ! lsmod | grep -q "${module%.ko}"; then
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
        if ! lsmod | grep -q xt_multiport; then
            log_warning_terminal "
  Модуль multiport не найден
  Невозможно использовать указанные порты без него
  Установите компонент роутера '${yellow}Модули ядра подсистемы Netfilter${reset}'
  
  Без модуля multiport прокси будет работать на всех портах
"
            port_donor=""
            port_exclude=""
        fi
    fi
}

strip_json_comments() {
    sed ':a; s:/\*[^*]*\*[^/]*\*/::g; ta; s/[[:space:]]*\/\/.*$//' "$@"
}

# Получение порта для Redirect
get_port_redirect() {
    if [ "$name_client" = "mihomo" ]; then
        port=$(yq eval '.redir-port // ""' "$mihomo_config" 2>/dev/null)
        [ -n "$port" ] && echo "$port" && return 0
    else
        for file in "$directory_xray_config"/*.json; do
            [ -f "$file" ] || continue

            port=$(
                strip_json_comments "$file" |
                jq -r '
                    .inbounds[]? |
                    select(
                        (.protocol == "dokodemo-door" or .protocol == "tunnel") and
                        .tag == "redirect" and
                        (.streamSettings.sockopt.tproxy? // "") != "tproxy"
                    ) |
                    .port
                ' 2>/dev/null |
                grep -v null |
                head -n1
            )

            [ -n "$port" ] && echo "$port" && return 0
        done
    fi

    echo "$port_redirect"
}

# Получение порта для TProxy
get_port_tproxy() {
    if [ "$name_client" = "mihomo" ]; then
        port=$(yq eval '.tproxy-port // ""' "$mihomo_config" 2>/dev/null)
        if [ -z "$port" ]; then
            port=$(yq eval '.listeners[] | select(.name == "tproxy" ) | .port // ""' "$mihomo_config" 2>/dev/null)
        fi
        [ -n "$port" ] && echo "$port" && return 0
    else
        for file in "$directory_xray_config"/*.json; do
            [ -f "$file" ] || continue

            port=$(
                strip_json_comments "$file" |
                jq -r '
                    .inbounds[]? |
                    select(
                        (.protocol == "dokodemo-door" or .protocol == "tunnel") and
                        .tag == "tproxy" and
                        (.streamSettings.sockopt.tproxy? // "") == "tproxy"
                    ) |
                    .port
                ' 2>/dev/null |
                grep -v null |
                head -n1
            )
            
            [ -n "$port" ] && echo "$port" && return 0
        done
    fi

    echo "$port_tproxy"
}

# Получение сети для Redirect
get_network_redirect() {
    if [ "$name_client" = "mihomo" ]; then
        [ -n "$port_redirect" ] && echo "tcp" && return 0
        echo "" && return 0
    else
        for file in "$directory_xray_config"/*.json; do
            [ -f "$file" ] || continue

            network=$(
                strip_json_comments "$file" |
                jq -r '
                    .inbounds[]? |
                    select(
                        (.protocol == "dokodemo-door" or .protocol == "tunnel") and
                        .tag == "redirect" and
                        (.streamSettings.sockopt.tproxy? // "") != "tproxy"
                    ) |
                    .settings.network // ""
                ' 2>/dev/null |
                tr -d "[:space:]" |
                tr "," " " |
                grep -v null |
                head -n1
            )

            [ -n "$network" ] && echo "$network" && return 0
        done

        echo "" && return 0
    fi
}

# Получение сети для TProxy
get_network_tproxy() {
    if [ "$name_client" = "mihomo" ]; then
        if [ -n "$port_redirect" ] && [ -n "$port_tproxy" ]; then
            echo "udp"
        elif [ -z "$port_redirect" ] && [ -n "$port_tproxy" ]; then
            echo "tcp udp"
        else
            echo ""
        fi
        return 0
    else
        for file in "$directory_xray_config"/*.json; do
            [ -f "$file" ] || continue

            network=$(
                strip_json_comments "$file" |
                jq -r '
                    .inbounds[]? |
                    select(
                        (.protocol == "dokodemo-door" or .protocol == "tunnel") and
                        .tag == "tproxy" and
                        (.streamSettings.sockopt.tproxy? // "") == "tproxy"
                    ) |
                    .settings.network // ""
                ' 2>/dev/null |
                tr -d "[:space:]" |
                tr "," " " |
                grep -v null |
                head -n1
            )

            [ -n "$network" ] && echo "$network" && return 0
        done

        echo "" && return 0
    fi
}

# Получение исключенных портов
get_port_exclude() {
    result=$(curl -kfsS "${url_server}/${url_redirect_port}" 2>/dev/null)
    port_exclude_redirect=$(echo "$result" | jq -r '.[] | if has("to-port") then .["to-port"] else .port end' 2>/dev/null |
        grep -E -v '(^|,)80($|,)|(^|,)443($|,)' | tr '\n' ',' | sed 's/,$//')
    if [ -n "$port_exclude" ]; then
        port_exclude="$port_exclude,$port_exclude_redirect"
    else
        port_exclude="$port_exclude_redirect"
    fi
    port_exclude=$(echo "$port_exclude" | tr -dc '0-9,:' | sed 's/,,*/,/g; s/^,//; s/,$//')
    echo "$port_exclude"
}

# Получение исключений IPv4
get_exclude_ip4() {
    [ "$iptables_supported" != "true" ] && return

    # Получаем провайдерский IPv4
    ipv4_eth=$(ip route get 195.208.4.1 2>/dev/null | grep -o 'src [0-9.]\+' | awk '{print $2}' ||
               ip route get 77.88.8.8 2>/dev/null | grep -o 'src [0-9.]\+' | awk '{print $2}')
    [ -n "$ipv4_eth" ] && ipv4_eth="${ipv4_eth}/32"
    user_ipv4=$(get_user_ipv4_excludes)
    echo "${ipv4_eth} ${ipv4_exclude}${user_ipv4}" | tr ' ' '\n' | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/^ //; s/ $//'
}

# Получение исключений IPv6
get_exclude_ip6() {
    [ "$ip6tables_supported" != "true" ] && return

    # Получаем провайдерский IPv6
    ipv6_eth=$(ip -6 route get 2a0c:a9c7:8::1 2>/dev/null | awk -F 'src ' '{print $2}' | awk '{print $1}' ||
               ip -6 route get 2a02:6b8::feed:0ff 2>/dev/null | awk -F 'src ' '{print $2}' | awk '{print $1}')
    [ -n "$ipv6_eth" ] && ipv6_eth="${ipv6_eth}/128"
    user_ipv6=$(get_user_ipv6_excludes)
    echo "${ipv6_eth} ${ipv6_exclude}${user_ipv6}" | tr ' ' '\n' | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/^ //; s/ $//'
}

# Получение метки политики
get_policy_mark() {
    policy_mark=$(curl -kfsS "${url_server}/${url_policy}" 2>/dev/null |
        jq -r ".[] | select(.description | ascii_downcase == \"${name_policy}\") | .mark" 2>/dev/null)

    if [ -n "$policy_mark" ]; then
        echo "0x${policy_mark}"
    else
        echo ""
    fi
}

# Получаем пользовательские политики
get_user_policies() {
    [ ! -f "$xkeen_config" ] && return
    jq -r '.xkeen.policy[]? | "\(.name)|\(.port // "")" ' "$xkeen_config" 2>/dev/null
}

# Проверка на конфликт имен политик
check_policy_name_conflict() {
    if [ -f "$xkeen_config" ]; then
        conflict=$(jq -r --arg main "$name_policy" '.xkeen.policy[] | select((.name | ascii_downcase) == ($main | ascii_downcase)) | .name' "$xkeen_config" 2>/dev/null | head -n 1)

        if [ -n "$conflict" ]; then
            log_error_router "Ошибка конфигурации: Имя политики в xkeen.json совпадает с системным"
            log_error_terminal "
  В файле ${yellow}xkeen.json${reset} найдена политика с именем '${red}${conflict}${reset}'
  Это имя зарезервировано основной службой XKeen
  
  Переименуйте пользовательскую политику в json-файле
  Запуск ${yellow}$name_client${reset} ${red}отменен${reset}
"
            exit 1
        fi
    fi
}

# Получаем порты пользовательских политик
resolve_user_policies() {
    get_user_policies | while IFS='|' read -r pname pports; do
        mark=$(curl -kfsS "${url_server}/${url_policy}" 2>/dev/null |
            jq -r ".[] | select(.description | ascii_downcase == \"${pname}\") | .mark" 2>/dev/null)

        [ -z "$mark" ] && continue

        if [ -z "$pports" ]; then
            # Порты не указаны -> режим "all" (все порты)
            mode="all"
            clean_ports=""
        else
            case "$pports" in
                !*)
                    mode="exclude"
                    ports="${pports#!}"
                    ;;
                *)
                    mode="include"
                    ports="$pports"
                    ;;
            esac

            if [ -n "${file_dns}" ] && [ "$proxy_dns" = "on" ] && [ "$mode" = "include" ]; then
                echo "$ports" | tr ',' '\n' | grep -q '^53$' || ports="53,$ports"
            fi

            clean_ports=$(validate_and_clean_ports "$ports")
            [ -z "$clean_ports" ] && continue
        fi

        echo "${mark}|${mode}|${clean_ports}"
    done
}

# Получение режима прокси-клиента
get_mode_proxy() {
    if [ -n "$port_redirect" ] && [ -n "$port_tproxy" ]; then
        mode_proxy="Mixed"
    elif [ -n "$port_tproxy" ]; then
        mode_proxy="TProxy"
    elif [ -n "$port_redirect" ]; then
        mode_proxy="Redirect"
    else
        mode_proxy="Other"
    fi
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
policy_mark="$policy_mark"
user_policies="$user_policies"
table_redirect="$table_redirect"
table_tproxy="$table_tproxy"
table_mark="$table_mark"
table_id="$table_id"
file_dns="$file_dns"
proxy_dns="$proxy_dns"
directory_os_modules="$directory_os_modules"
directory_user_modules="$directory_user_modules"
directory_configs_app="$directory_configs_app"
directory_xray_config="$directory_xray_config"
directory_xray_asset="$directory_xray_asset"
iptables_supported=$iptables_supported
ip6tables_supported=$ip6tables_supported
arm64_fd=$arm64_fd
other_fd=$other_fd

# Перезапуск скрипта
restart_script() {
    exec /bin/sh "\$0" "\$@"
}

if pidof "\$name_client" >/dev/null; then

    ipt() {
        if [ "\$family" = "iptables" ] && [ "\$iptables_supported" = "true" ]; then
            iptables -w -t "\$table" "\$@"
        elif [ "\$family" = "ip6tables" ] && [ "\$ip6tables_supported" = "true" ]; then
            ip6tables -w -t "\$table" "\$@"
        fi
    }

    # Добавление правил-исключений
    add_exclude_rules() {
        chain="\$1"
        for exclude in \$exclude_list; do
            if [ "\$exclude" = "10.0.0.0/8" ] || [ "\$exclude" = "172.16.0.0/12" ] || [ "\$exclude" = "192.168.0.0/16" ] || [ "\$exclude" = "fd00::/8" ] || [ "\$exclude" = "fe80::/10" ] && [ "\$chain" != "\$name_output_chain" ] && [ -n "\$file_dns" ] && [ "\$proxy_dns" = "on" ]; then
                if [ "\$table" = "mangle" ] && [ "\$mode_proxy" = "Mixed" ]; then
                    ipt -A "\$chain" -d "\$exclude" -p tcp --dport 53 -j RETURN >/dev/null 2>&1
                    ipt -A "\$chain" -d "\$exclude" -p udp ! --dport 53 -j RETURN >/dev/null 2>&1
                elif [ "\$table" = "nat" ] && [ "\$mode_proxy" = "Mixed" ]; then
                    ipt -A "\$chain" -d "\$exclude" -p tcp ! --dport 53 -j RETURN >/dev/null 2>&1
                    ipt -A "\$chain" -d "\$exclude" -p udp --dport 53 -j RETURN >/dev/null 2>&1
                elif [ "\$table" = "mangle" ] && [ "\$mode_proxy" = "TProxy" ]; then
                    ipt -A "\$chain" -d "\$exclude" -p tcp ! --dport 53 -j RETURN >/dev/null 2>&1
                    ipt -A "\$chain" -d "\$exclude" -p udp ! --dport 53 -j RETURN >/dev/null 2>&1
                fi
            else
                ipt -A "\$chain" -d "\$exclude" -j RETURN >/dev/null 2>&1
            fi
        done
    }

    # Добавление правил iptables
    add_ipt_rule() {
        family="\$1"
        table="\$2"
        chain="\$3"
        shift 3
        [ "\$family" = "iptables" ] && [ "\$iptables_supported" = "false" ] && return
        [ "\$family" = "ip6tables" ] && [ "\$ip6tables_supported" = "false" ] && return

        if ! ipt -nL \$name_prerouting_chain >/dev/null 2>&1; then
            ipt -N \$name_prerouting_chain || exit 0
            add_exclude_rules \$name_prerouting_chain

            case "\$mode_proxy" in
                Mixed)
                    if [ "\$table" = "\$table_redirect" ]; then
                        ipt -I \$name_prerouting_chain 1 -m conntrack --ctstate DNAT -j RETURN >/dev/null 2>&1
                        ipt -A \$name_prerouting_chain -p tcp -j REDIRECT --to-port "\$port_redirect" >/dev/null 2>&1
                    else
                        ipt -I \$name_prerouting_chain 1 -m conntrack --ctstate DNAT -j RETURN >/dev/null 2>&1
                        ipt -A \$name_prerouting_chain -p udp -m socket --transparent -j MARK --set-mark "\$table_mark" >/dev/null 2>&1
                        ipt -A \$name_prerouting_chain -p udp -j CONNMARK --save-mark >/dev/null 2>&1
                        ipt -A \$name_prerouting_chain -p udp -j TPROXY --on-ip "\$proxy_ip" --on-port "\$port_tproxy" --tproxy-mark "\$table_mark" >/dev/null 2>&1
                    fi
                    ;;
                TProxy)
                    for net in \$network_tproxy; do
                        ipt -C \$name_prerouting_chain -m conntrack --ctstate DNAT -j RETURN >/dev/null 2>&1 ||
                        ipt -I \$name_prerouting_chain 1 -m conntrack --ctstate DNAT -j RETURN
                        ipt -A \$name_prerouting_chain -p "\$net" -m socket --transparent -j MARK --set-mark "\$table_mark" >/dev/null 2>&1
                        ipt -A \$name_prerouting_chain -p "\$net" -j CONNMARK --save-mark >/dev/null 2>&1
                        ipt -A \$name_prerouting_chain -p "\$net" -j TPROXY --on-ip "\$proxy_ip" --on-port "\$port_tproxy" --tproxy-mark "\$table_mark" >/dev/null 2>&1
                    done
                    ;;
                Redirect)
                    for net in \$network_redirect; do
                        ipt -C \$name_prerouting_chain -m conntrack --ctstate DNAT -j RETURN >/dev/null 2>&1 ||
                        ipt -I \$name_prerouting_chain 1 -m conntrack --ctstate DNAT -j RETURN
                        ipt -A \$name_prerouting_chain -p "\$net" -j REDIRECT --to-port "\$port_redirect" >/dev/null 2>&1
                    done
                    ;;
                *) exit 0 ;;
            esac
        fi

        if [ "\$table" = "\$table_tproxy" ]; then
            ipt -N \$name_output_chain 2>/dev/null || true
            ipt -F \$name_output_chain
            add_exclude_rules \$name_output_chain
            for net in \$network_tproxy; do
                ipt -A \$name_output_chain -p "\$net" -j CONNMARK --set-mark "\$table_mark" >/dev/null 2>&1
            done
        fi
    }

    # Настройка таблицы маршрутов
    configure_route() {
        ip_version="\$1"

        # Определяем таблицу маршрутизации
        if [ -n "\$policy_mark" ]; then
            policy_table=\$(ip rule show | awk -v policy="\$policy_mark" '\$0 ~ policy && /lookup/ && !/blackhole/ {print \$(NF)}' | sed -n '1p')
            source_table="\$policy_table"
        else
            source_table="main"
        fi

        # Проверяем есть ли default маршрут
        check_default() {
            if [ \$ip_version = 6 ] && ! ip -6 route show default 2>/dev/null | grep -q .; then
                return 0
            fi
            if [ "\$source_table" = "main" ]; then
                ip -\$ip_version route show default 2>/dev/null | grep -q '^default'
            else
                ip -\$ip_version route show table all 2>/dev/null | grep -E "^[[:space:]]*default .* table \$policy_table([[:space:]]|$)" | grep -vq 'unreachable' >/dev/null
            fi
        }

        attempts=0
        max_attempts=4
        until check_default; do
            attempts=\$((attempts + 1))
            if [ "\$attempts" -ge "\$max_attempts" ]; then
                [ "\$ip_version" = 4 ] && touch "/tmp/noinet"
                return 1
            fi
            sleep 1
        done
        [ "\$ip_version" = 4 ] && rm -f "/tmp/noinet"

        ip -\$ip_version rule del fwmark \$table_mark lookup \$table_id >/dev/null 2>&1 || true
        ip -\$ip_version route flush table \$table_id >/dev/null 2>&1 || true
        ip -\$ip_version route add local default dev lo table \$table_id >/dev/null 2>&1 || true
        ip -\$ip_version rule add fwmark \$table_mark lookup \$table_id >/dev/null 2>&1 || true

        # Копируем маршруты
        ip -\$ip_version route show table \$source_table 2>/dev/null | while read -r route_line; do
            case "\$route_line" in
                default*|unreachable*|blackhole*) continue ;;
                *) ip -\$ip_version route add table \$table_id \$route_line >/dev/null 2>&1 || true ;;
            esac
        done
        return 0
    }

    # Создание множественных правил multiport
    add_multiport_rules() {
        family="\$1"
        table="\$2"
        net="\$3"
        connmark="\$4"
        ports="\$5"
        mode="\$6"

        [ -z "\$ports" ] && return

        if [ "\$mode" = "exclude" ]; then
            dports_opt="! --dports"
        else
            dports_opt="--dports"
        fi

        num_ports=\$(echo "\$ports" | tr ',' '\n' | sed '/^$/d' | wc -l)
        [ "\$num_ports" -eq 0 ] && return

        i=1
        while [ "\$i" -le "\$num_ports" ]; do
            end=\$((i + 6))
            chunk=\$(echo "\$ports" | tr ',' '\n' | sed '/^$/d' | sed -n "\${i},\${end}p" | tr '\n' ',' | sed 's/,$//')
            [ -z "\$chunk" ] && break
            rule="-m connmark --mark \$connmark -m conntrack ! --ctstate INVALID -p \$net -m multiport \$dports_opt \$chunk -j \$name_prerouting_chain"
            ipt -C PREROUTING \$rule >/dev/null 2>&1 || ipt -A PREROUTING \$rule
            i=\$((i + 7))
        done
    }

    # Добавление цепочек PREROUTING
    add_prerouting() {
        family="\$1"
        table="\$2"

        for net in \$networks; do
            if [ "\$mode_proxy" = "Mixed" ]; then
                [ "\$table" = "nat"    ] && [ "\$net" != "tcp" ] && continue
                [ "\$table" = "mangle" ] && [ "\$net" != "udp" ] && continue
            fi

            # Пользовательские политики из xkeen.json
            echo "\$user_policies" | while IFS='|' read -r pmark pmode pports; do
                [ -z "\$pmark" ] && continue

                # Если режим "all" (порты не заданы) - проксируем все порты
                if [ "\$pmode" = "all" ]; then
                    ipt -C PREROUTING -m connmark --mark "0x\$pmark" -m conntrack ! --ctstate INVALID -j "\$name_prerouting_chain" >/dev/null 2>&1 ||
                    ipt -A PREROUTING -m connmark --mark "0x\$pmark" -m conntrack ! --ctstate INVALID -j "\$name_prerouting_chain"
                else
                    # Иначе используем конкретные порты
                    add_multiport_rules "\$family" "\$table" "\$net" "0x\$pmark" "\$pports" "\$pmode"
                fi
            done
    
            # Политика xkeen (стандартная)
            if [ -n "\$policy_mark" ]; then

                if [ -n "\$port_donor" ]; then
                    add_multiport_rules "\$family" "\$table" "\$net" "\$policy_mark" "\$port_donor" include
                elif [ -n "\$port_exclude" ]; then
                    add_multiport_rules "\$family" "\$table" "\$net" "\$policy_mark" "\$port_exclude" exclude
                else
                    # Политика xkeen, когда порты не указаны (проксирование на всех портах)
                    ipt -C PREROUTING -m connmark --mark "\$policy_mark" -m conntrack ! --ctstate INVALID -j "\$name_prerouting_chain" >/dev/null 2>&1 ||
                    ipt -A PREROUTING -m connmark --mark "\$policy_mark" -m conntrack ! --ctstate INVALID -j "\$name_prerouting_chain"
                fi
            elif [ -z "\$user_policies" ]; then
                # Если нет ни xkeen, ни пользовательских политик -> перехватываем всё (без connmark)
                ipt -C PREROUTING -m conntrack ! --ctstate INVALID -j "\$name_prerouting_chain" >/dev/null 2>&1 ||
                ipt -A PREROUTING -m conntrack ! --ctstate INVALID -j "\$name_prerouting_chain"
            fi
        done
    }

    dns_redir() {
        family="\$1"
        table="nat"

        all_marks=""
        [ -n "\$policy_mark" ] && all_marks="\$policy_mark"
        
        if [ -n "\$user_policies" ]; then
            user_marks=\$(echo "\$user_policies" | awk -F'|' '{if (\$1 != "") print "0x"\$1}')
            all_marks="\$all_marks \$user_marks"
        fi

        for mark in \$all_marks; do
            [ -z "\$mark" ] && continue
            for proto in udp tcp; do
                ipt -C _NDM_HOTSPOT_DNSREDIR -p "\$proto" -m mark --mark "\$mark" -m pkttype --pkt-type unicast -m "\$proto" --dport 53 -j REDIRECT --to-ports 53 >/dev/null 2>&1 ||
                ipt -I _NDM_HOTSPOT_DNSREDIR -p "\$proto" -m mark --mark "\$mark" -m pkttype --pkt-type unicast -m "\$proto" --dport 53 -j REDIRECT --to-ports 53
            done
        done
    }

    [ -n "\$policy_mark" ] && connmark_option="-m connmark --mark \$policy_mark"
    if [ -n "\$port_donor" ] || [ -n "\$port_exclude" ]; then
        [ -n "\$file_dns" ] && [ "\$proxy_dns" = "on" ] && [ -n "\$port_donor" ] && port_donor="53,\$port_donor"
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

        dns_redir "\$family"
    done
else
    . "/opt/sbin/.xkeen/01_info/03_info_cpu.sh"
    status_file="/opt/lib/opkg/status"
    info_cpu
    case "\$name_client" in
        xray)
            export XRAY_LOCATION_CONFDIR="\$directory_xray_config"
            export XRAY_LOCATION_ASSET="\$directory_xray_asset"
            if [ "\$architecture" = "arm64-v8a" ]; then
                ulimit -SHn "\$arm64_fd" && su -c "\$name_client run" "\$name_profile" >/dev/null 2>&1 &
            else
                ulimit -SHn "\$other_fd" && su -c "\$name_client run" "\$name_profile" >/dev/null 2>&1 &
            fi
        ;;
        mihomo)
            export CLASH_HOME_DIR="\$directory_configs_app"
            if [ "\$architecture" = "arm64-v8a" ]; then
                ulimit -SHn "\$arm64_fd" && su -c "\$name_client" "\$name_profile" >/dev/null 2>&1 &
            else
                ulimit -SHn "\$other_fd" && su -c "\$name_client" "\$name_profile" >/dev/null 2>&1 &
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

    dns_p_mark=$(get_policy_mark)
    dns_all_marks=""
    [ -n "$dns_p_mark" ] && dns_all_marks="$dns_p_mark"
    dns_u_policies=$(resolve_user_policies)
    if [ -n "$dns_u_policies" ]; then
        dns_u_marks=$(echo "$dns_u_policies" | awk -F'|' '{if ($1 != "") print "0x"$1}')
        dns_all_marks="$dns_all_marks $dns_u_marks"
    fi

    for family in iptables ip6tables; do
        [ "$family" = "iptables" ] && [ "$iptables_supported" != "true" ] && continue
        [ "$family" = "ip6tables" ] && [ "$ip6tables_supported" != "true" ] && continue

        for mark in $dns_all_marks; do
            [ -z "$mark" ] && continue
            for proto in udp tcp; do
                while "$family" -w -t nat -C _NDM_HOTSPOT_DNSREDIR -p "$proto" -m mark --mark "$mark" -m pkttype --pkt-type unicast -m "$proto" --dport 53 -j REDIRECT --to-ports 53 >/dev/null 2>&1; do
                    "$family" -w -t nat -D _NDM_HOTSPOT_DNSREDIR -p "$proto" -m mark --mark "$mark" -m pkttype --pkt-type unicast -m "$proto" --dport 53 -j REDIRECT --to-ports 53 >/dev/null 2>&1
                done
            done
        done
    done

    clean_run() {
        family="$1"
        table="$2"
        name_chain="$3"

        if "$family" -w -t "$table" -nL "$name_chain" >/dev/null 2>&1; then
            "$family" -w -t "$table" -F "$name_chain" >/dev/null 2>&1

            while "$family" -w -t "$table" -nL PREROUTING | grep -q "$name_chain"; do
                rule_number=$("$family" -w -t "$table" -nL PREROUTING --line-numbers | grep -m 1 "$name_chain" | awk '{print $1}')
                "$family" -w -t "$table" -D PREROUTING "$rule_number" >/dev/null 2>&1
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

# Мониторинг файловых дескрипторов
monitor_fd() {
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

missing_files_template='
  '"${light_blue}"'Отсутствуют исполняемые файлы:'"${reset}"'
  '"${yellow}"'%s'"${reset}"'

  '"${green}"'Возможные причины:'"${reset}"'
  • XKeen установлен во внутреннюю память и на ней недостаточно места
  • У файла отсутствуют права на выполнение

  '"${green}"'Рекомендуемые действия:'"${reset}"'
  1. Переустановите XKeen на внешний накопитель
  2. Либо скопируйте недостающий файл вручную и сделайте исполняемым
'

# Запуск прокси-клиента
proxy_start() {
    start_manual="$1"
    validate_xkeen_json
    check_policy_name_conflict
    if [ "$start_manual" = "on" ] || [ "$start_auto" = "on" ]; then
        log_clean
        process_user_ports
        port_redirect=$(get_port_redirect)
        network_redirect=$(get_network_redirect)
        port_tproxy=$(get_port_tproxy)
        network_tproxy=$(get_network_tproxy)
        mode_proxy=$(get_mode_proxy)
        if [ "$mode_proxy" != "Other" ]; then
            policy_mark=$(get_policy_mark)
            
            # Проверка наличия политики xkeen и пользовательских политик
            if [ -n "$policy_mark" ]; then
                user_policies=$(resolve_user_policies)
            else
                # Если xkeen не найдена, проверяем, были ли заданы user policies
                raw_user_policies=$(get_user_policies)
                
                if [ -n "$raw_user_policies" ]; then
                    log_warning_terminal "
  Политика '${green}$name_policy${reset}' не найдена в веб-интерфейсе роутера
  Пользовательские политики из '${yellow}xkeen.json${reset}' будут проигнорированы
  Прокси будет запущен для всего устройства
"
                else
                    log_warning_terminal "
  Политика '${green}$name_policy${reset}' не найдена в веб-интерфейсе роутера
  Прокси будет запущен для всего устройства
"
                fi
                # Принудительно очищаем user_policies, чтобы сработал fallback
                user_policies=""
            fi

            networks=$(echo "$network_redirect $network_tproxy" | tr ',' ' ' | tr -s ' ' | sort -u | tr '\n' ' ' | sed 's/^ //; s/ $//')
            if [ -n "$policy_mark" ] && [ -z "$port_donor" ]; then
                port_exclude=$(get_port_exclude)
            fi
            if ! proxy_status && { [ -n "$port_donor" ] || [ -n "$port_exclude" ] || [ "$mode_proxy" = "TProxy" ] || [ "$mode_proxy" = "Mixed" ]; }; then
                get_modules
            fi
            if [ "$mode_proxy" = "TProxy" ]; then
                keenetic_ssl="$(get_keenetic_port)" || {
                    log_error_router "Порт 443 занят сервисами Keenetic"
                    log_error_terminal "
  Необходимый для режима ${yellow}TProxy${reset} ${red}443 порт занят${reset} сервисами Keenetic

  Освободите его на странице 'Пользователи и доступ' веб-интерфейса роутера
"
                    proxy_stop
                    exit 1
                }
            fi
        fi
        if proxy_status; then
            echo -e "  Прокси-клиент уже ${green}запущен${reset}"
            [ "$mode_proxy" != "Other" ] && configure_firewall
            if [ "$start_manual" = "on" ]; then
                log_error_terminal "Не удалось запустить $name_client, так как он уже запущен"
            else
                log_info_router "Прокси-клиент успешно запущен в режиме $mode_proxy"
            fi
        else
            log_info_router "Инициирован запуск прокси-клиента"
            delay_increment=1
            current_delay=0
            [ "$start_manual" != "on" ] && current_delay=$start_delay
            attempt=1
            create_user
            . "/opt/sbin/.xkeen/01_info/03_info_cpu.sh"
            status_file="/opt/lib/opkg/status"
            info_cpu
            install_dir="/opt/sbin"
            while [ "$attempt" -le "$start_attempts" ]; do
                case "$name_client" in
                    xray)
                        if [ ! -x "$install_dir/xray" ]; then
                            missing_files="$install_dir/xray"
                            log_error_terminal "$(printf "$missing_files_template" "$missing_files")"
                            exit 1
                        fi
                        export XRAY_LOCATION_CONFDIR="$directory_xray_config"
                        export XRAY_LOCATION_ASSET="$directory_xray_asset"
                        find "$directory_xray_config" -maxdepth 1 -name '._*.json' -type f -delete
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
                        if [ ! -x "$install_dir/mihomo" ] || [ ! -x "$install_dir/yq" ]; then
                            missing_files=""
                            [ ! -x "$install_dir/yq" ] && missing_files="$install_dir/yq"
                            [ ! -x "$install_dir/mihomo" ] && missing_files="$install_dir/mihomo\n  $missing_files"
                            log_error_terminal "$(printf "$missing_files_template" "$missing_files")"
                            exit 1
                        fi
                        export CLASH_HOME_DIR="$directory_configs_app"
                        if [ "$architecture" = "arm64-v8a" ]; then
                            if [ -n "$fd_out" ]; then
                                ulimit -SHn "$arm64_fd" && nohup su -c "$name_client" "$name_profile" >/dev/null 2>&1 &
                                unset fd_out
                            else
                                ulimit -SHn "$arm64_fd" && su -c "$name_client" "$name_profile" &
                            fi
                        else
                            if [ -n "$fd_out" ]; then
                                ulimit -SHn "$other_fd" && nohup su -c "$name_client" "$name_profile" >/dev/null 2>&1 &
                                unset fd_out
                            else
                                ulimit -SHn "$other_fd" && su -c "$name_client" "$name_profile" &
                            fi
                        fi
                        ;;
                    *) "$name_client" run -C "$directory_xray_config" & ;;
                esac
                sleep 2 && sleep "$current_delay"
                if proxy_status; then
                    [ "$mode_proxy" != "Other" ] && configure_firewall
                    echo -e "  Прокси-клиент ${green}запущен${reset} в режиме ${yellow}${mode_proxy}${reset}"
                    if curl -kfsS "${url_server}/${url_policy}" | jq --arg policy "$name_policy" -e 'any(.[]; .description | ascii_downcase == $policy)' > /dev/null; then
                        if [ -e "/tmp/noinet" ]; then
                            echo
                            echo -e "  У политики ${yellow}$name_policy${reset} ${red}нет доступа в интернет${reset}"
                            echo "  Проверьте, установлена ли галка на подключении к провайдеру"
                        fi
                    fi
                    [ "$mode_proxy" = "Other" ] && echo -e "  Функция прозрачного прокси ${red}не активна${reset}. Направляйте соединения на ${yellow}${name_client}${reset} вручную"
                    log_info_router "Прокси-клиент успешно запущен в режиме $mode_proxy"
                    if [ "$check_fd" = "on" ] && [ ! -f "/tmp/observer_fd" ]; then
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
        current_delay=0
        attempt=1
        while [ "$attempt" -le "$start_attempts" ]; do
            clean_firewall
            killall -q -9 "$name_client"
                sleep 1 && sleep "$current_delay"
            if ! proxy_status; then
                echo -e "  Прокси-клиент ${red}остановлен${reset}"
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
            mode_proxy=$(grep '^mode_proxy=' $file_netfilter_hook | awk -F'"' '{print $2}')
            echo -e "  Прокси-клиент ${yellow}$name_client${reset} ${green}запущен${reset} в режиме ${yellow}$mode_proxy${reset}"
        else
            echo -e "  Прокси-клиент ${red}не запущен${reset}"
        fi
        ;;
    restart) proxy_stop; proxy_start "$2" ;;
    *) echo -e "  Команды: ${green}start${reset} | ${red}stop${reset} | ${yellow}restart${reset} | status" ;;
esac

exit 0