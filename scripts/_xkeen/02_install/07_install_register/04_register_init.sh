#!/bin/sh

# Информация о службе: Запуск / Остановка XKeen
# Версия: 2.30

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

# Директории
directory_os_modules="/lib/modules/$(uname -r)"
directory_user_modules="/opt/lib/modules"
directory_configs_app="/opt/etc/$name_client"
directory_xray_config="$directory_configs_app/configs"
directory_xray_asset="$directory_configs_app/dat"
directory_logs="/opt/var/log"
xkeen_cfg="/opt/etc/xkeen"
ipset_cfg="$xkeen_cfg/ipset"
install_dir="/opt/sbin"

# Файлы
file_netfilter_hook="/opt/etc/ndm/netfilter.d/proxy.sh"
log_access="$directory_logs/$name_client/access.log"
log_error="$directory_logs/$name_client/error.log"
mihomo_config="$directory_configs_app/config.yaml"
file_port_proxying="$xkeen_cfg/port_proxying.lst"
file_port_exclude="$xkeen_cfg/port_exclude.lst"
file_ip_exclude="$xkeen_cfg/ip_exclude.lst"
xkeen_config="$xkeen_cfg/xkeen.json"
file_pid_fd="/var/run/xkeen_fd.pid"
ru_exclude_ipv4="$ipset_cfg/ru_exclude_ipv4.lst"
ru_exclude_ipv6="$ipset_cfg/ru_exclude_ipv6.lst"

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
comment_tag="xkeen_rule"
comment="-m comment --comment $comment_tag"
custom_mark=""

# DSCP-метки
dscp_exclude="62"
dscp_proxy="63"

ipv4_proxy="127.0.0.1"
ipv4_exclude="0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 255.255.255.255"
ipv6_proxy="::1"
ipv6_exclude="::/128 ::1/128 64:ff9b::/96 2001::/32 2002::/16 fd00::/8 ff00::/8 fe80::/10"

# Перехват DNS в прокси
proxy_dns="off"

# Проксирование трафика Entware
proxy_router="off"

# Настройки запуска
start_attempts=10
start_auto="on"
start_delay=20

# Контроль файловых дескрипторов
check_fd="off"
arm64_fd=40000
other_fd=10000
delay_fd=60

# Поддержка IPv6
ipv6_support="on"

## Расширенные сообщения запуска
extended_msg="off"

## Резервное копирование XKeen при обновлении
backup="on"

## Клиенты XKeen под своими IP в журнале AdGuard Home
aghfix="off"

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

log_info_terminal() {
    echo
    echo -e "${green}Информация${reset}: $1" >&2
}

log_warning_terminal() {
    echo
    echo -e "${yellow}Предупреждение${reset}: $1" >&2
}

log_error_terminal() {
    echo
    echo -e "${red}Ошибка${reset}: $1" >&2
    exit 1
}

print_policy_info() {
    found="$1"
    has_custom="$2"
    ignored_custom="$3"

    ignore_line=""
    if [ "$ignored_custom" = "yes" ]; then
        ignore_line="
  Пользовательские политики из '${yellow}xkeen.json${reset}' будут проигнорированы"
    fi

    if [ "$extended_msg" != "on" ]; then
        if [ "$found" = "no" ]; then
            log_info_terminal "
  Политика '${yellow}$name_policy${reset}' не найдена в веб-интерфейсе роутера${ignore_line}
  Прокси будет запущен для всего устройства
"
        fi
        return
    fi

    if [ "$found" = "yes" ]; then

        if [ "$has_custom" = "yes" ]; then
            custom_names=$(echo "$user_policies" | cut -d'|' -f1 | tr '\n' ',' | sed 's/,$//; s/,/, /g')
            policies="${name_policy}, ${custom_names}"

            detail_list=""
            if [ -n "$port_donor" ]; then
                detail_list="  - ${yellow}$name_policy${reset} на портах ${green}${port_donor}${reset}"
            elif [ -n "$port_exclude" ]; then
                detail_list="  - ${yellow}$name_policy${reset} на всех портах кроме ${green}${port_exclude}${reset}"
            else
                detail_list="  - ${yellow}$name_policy${reset} на всех портах"
            fi

            custom_details=$(echo "$user_policies" | while IFS='|' read -r p_name p_mark p_mode p_ports; do
                if [ "$p_mode" = "include" ]; then
                    echo "  - ${yellow}$p_name${reset} на портах ${green}${p_ports}${reset}"
                elif [ "$p_mode" = "exclude" ]; then
                    echo "  - ${yellow}$p_name${reset} на всех портах кроме ${green}${p_ports}${reset}"
                else
                    echo "  - ${yellow}$p_name${reset} на всех портах"
                fi
            done)

            log_info_terminal "
  Найдены политики '${yellow}${policies}${reset}'
  Прокси будет запущен для клиентов политик:
${detail_list}
${custom_details}
"
        else
            if [ -z "$port_donor" ] && [ -z "$port_exclude" ]; then
                log_info_terminal "
  Найдена политика '${yellow}$name_policy${reset}'
  Не определены целевые порты для XKeen
  Прокси будет запущен для клиентов политики '${yellow}$name_policy${reset}' на всех портах
"
            elif [ -n "$port_donor" ]; then
                log_info_terminal "
  Найдена политика '${yellow}$name_policy${reset}'
  Определены целевые порты для XKeen
  Прокси будет запущен для клиентов политики '${yellow}$name_policy${reset}'
  на портах ${green}${port_donor}${reset}
"
            else
                log_info_terminal "
  Найдена политика '${yellow}$name_policy${reset}'
  Определены порты исключения для XKeen
  Прокси будет запущен для клиентов политики '${yellow}$name_policy${reset}'
  на всех портах кроме ${green}${port_exclude}${reset}
"
            fi
        fi
    else
        if [ -n "$port_donor" ]; then
            log_info_terminal "
  Политика '${yellow}$name_policy${reset}' не найдена в веб-интерфейсе роутера${ignore_line}
  Определены целевые порты для XKeen
  Прокси будет запущен для всех клиентов
  на портах ${green}${port_donor}${reset}
"
        elif [ -n "$port_exclude" ]; then
            log_info_terminal "
  Политика '${yellow}$name_policy${reset}' не найдена в веб-интерфейсе роутера${ignore_line}
  Определены порты исключения для XKeen
  Прокси будет запущен для всех клиентов
  на всех портах кроме ${green}${port_exclude}${reset}
"
        else
            log_info_terminal "
  Политика '${yellow}$name_policy${reset}' не найдена в веб-интерфейсе роутера${ignore_line}
  Не определены целевые порты для XKeen
  Прокси будет запущен для всех клиентов на всех портах
"
        fi
    fi
}

for cmd in jq curl grep awk sed ipset; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
         log_error_terminal "Не найдена необходимая утилита: ${yellow}$cmd${reset}"
    fi
done

log_clean() {
    [ "$name_client" = "xray" ] && : > "$log_access" && : > "$log_error"
}

api_cache_init() {
    api_policy_json=$(curl -kfsS "${url_server}/${url_policy}" 2>/dev/null)
    api_port_json=$(curl -kfsS "${url_server}/${url_keenetic_port}" 2>/dev/null)
    api_static_json=$(curl -kfsS "${url_server}/${url_redirect_port}" 2>/dev/null)
}

refresh_port_cache() {
    api_port_json=$(curl -kfsS "${url_server}/${url_keenetic_port}" 2>/dev/null)
}

json_get_ports() {
    if [ -n "$api_port_json" ]; then
        printf '%s' "$api_port_json" | jq -r '.port, (.ssl.port // empty)' 2>/dev/null
    fi
}

# Получение портов Keenetic
get_keenetic_port() {
    ports=""
    ports=$(json_get_ports)

    case " $ports " in
        *" 443 "*) return 1 ;;
    esac

    if [ -z "$ports" ]; then
        ndmc -c 'ip http port 8080' >/dev/null 2>&1
        ndmc -c 'ip http port 80' >/dev/null 2>&1
        ndmc -c 'system configuration save' >/dev/null 2>&1
        sleep 2
        refresh_port_cache
        ports=$(json_get_ports)
    fi

    [ -n "$ports" ] || return 1

    echo "$ports"
    return 0
}

wait_for_webui() {
    max_wait=10
    i=0

    while [ "$i" -lt "$max_wait" ]; do
        pidof nginx >/dev/null 2>&1 && return 0
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

    sleep 5
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
    if [ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)" -eq 1 ] &&
       [ "$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null)" -eq 1 ]; then
        for dir in /proc/sys/net/ipv6/conf/t2s*; do
            [ -d "$dir" ] || continue
            [ -f "$dir/disable_ipv6" ] && echo "0" > "$dir/disable_ipv6"
        done
        log_info_router "Отключение IPv6 выполнено"
        return 0
    fi
}

get_ipver_support() {
    ip4_supported=$(ip -4 addr show 2>/dev/null | grep -q "inet " && echo true || echo false)
    ip6_supported=$(ip -6 addr show 2>/dev/null | grep -q "inet6 " && echo true || echo false)

    iptables_supported=$([ "$ip4_supported" = "true" ] && command -v iptables >/dev/null 2>&1 && echo true || echo false)
    ip6tables_supported=$([ "$ip6_supported" = "true" ] && command -v ip6tables >/dev/null 2>&1 && echo true || echo false)
}

strip_json_comments() {
    sed -e ':a; s:/\*[^*]*\*[^/]*\*/::g; ta' \
        -e 's/^[[:space:]]*\/\/.*$//' \
        -e 's/[[:space:]]\{1,\}\/\/.*$//' "$@"
}

# Функция валидации xkeen.json
validate_xkeen_json() {
    [ ! -f "$xkeen_config" ] && return 0
    if ! jq -e . "$xkeen_config" >/dev/null 2>&1; then
            log_error_terminal "
  Валидация JSON: файл '${yellow}xkeen.json${reset}' содержит синтаксические ошибки
  Запуск прокси невозможен
"
    fi

    if ! jq -e '.xkeen.policy[]? | .name' "$xkeen_config" >/dev/null 2>&1; then
        if jq -e '.xkeen' "$xkeen_config" >/dev/null 2>&1; then
            log_error_terminal "
  Файл '${yellow}xkeen.json${reset}' имеет неверную структуру
  Запуск прокси невозможен
"
        fi
    fi

    return 0
}

# Функция поиска резервных копий конфигурационных файлов Xray
check_xray_backups() {
    [ "$name_client" != "xray" ] && return 0

    # Ищем json-файлы с типичными признаками копий
    bad_files=$(find "$directory_xray_config" -maxdepth 1 -type f \( -iname "*bak*.json" -o -iname "*old*.json" -o -iname "*copy*.json" -o -iname "*копия*.json" -o -iname "*orig*.json" -o -iname "*save*.json" -o -iname "*temp*.json" -o -iname "*tmp*.json" -o -name "*(*).json" \))

    if [ -n "$bad_files" ]; then
        bad_list=$(printf '%s\n' "$bad_files" | awk -F/ '{print "  - " $NF}')
        
        log_error_terminal "
  В директории конфигурации Xray найдены резервные копии:
${light_blue}${bad_list}${reset}

  Измените расширение резервных копий, например, на ${yellow}.bak${reset}
  Либо переместите их в поддиректорию
  Запуск ${yellow}$name_client${reset} ${red}отменен${reset}
"
    fi
    return 0
}

# Функция проверки наличия метки 255
validate_routing_mark() {
    [ "$proxy_router" != "on" ] && return 0

    mark_valid="false"
    mark_msg=""
    bad_items=""
    has_items="false"
    all_marks_ok="true"

    if [ "$name_client" = "xray" ]; then
        mark_msg="mark"

        for file in "$directory_xray_config"/*.json; do
            [ -f "$file" ] || continue

            if strip_json_comments "$file" | jq -e '.outbounds != null' >/dev/null 2>&1; then
                has_items="true"

                current_bad=$(strip_json_comments "$file" | jq -r '
                    .outbounds[]? |
                    select(.protocol != "blackhole" and .protocol != "dns") |
                    select(.streamSettings.sockopt.mark != 255) |
                    (.tag // .protocol)
                ')

                if [ -n "$current_bad" ]; then
                     bad_items="${bad_items}${bad_items:+\n}$current_bad"
                    all_marks_ok="false"
                fi
            fi
        done

    elif [ "$name_client" = "mihomo" ]; then
        mark_msg="routing-mark"

        if [ -f "$mihomo_config" ]; then

            if yq -e '.["routing-mark"] == 255' "$mihomo_config" >/dev/null 2>&1; then
                mark_valid="true"
            elif yq -e '
                .proxy-providers[]? |
                select(.override."routing-mark" == 255)
            ' "$mihomo_config" >/dev/null 2>&1; then
                mark_valid="true"
            else

                if yq -e '.proxies != null' "$mihomo_config" >/dev/null 2>&1; then
                    has_items="true"
                    current_bad=$(yq -r '
                        .proxies[]? |
                        select(."routing-mark" != 255) |
                        .name
                    ' "$mihomo_config")

                    if [ -n "$current_bad" ]; then
                        bad_items="${bad_items}${bad_items:+\n}$current_bad"
                        all_marks_ok="false"
                    fi
                fi
            fi
        fi
    fi

    if [ "$mark_valid" != "true" ]; then
        if [ "$has_items" = "true" ] && [ "$all_marks_ok" = "true" ]; then
            mark_valid="true"
        fi
    fi

    if [ "$mark_valid" != "true" ]; then
        error_details=""

        if [ -n "$bad_items" ]; then
            bad_list=$(printf "%b\n" "$bad_items" | awk '!seen[$0]++ {print "  - " $0}')

            if [ "$name_client" = "xray" ]; then
                error_details="
  Подключения без метки:
${light_blue}${bad_list}${reset}"
                proxy_hint="  Добавьте маркировку во ВСЕ исходящие подключения (кроме blackhole и dns)"
            else
                error_details="
  Прокси без метки:
${light_blue}${bad_list}${reset}"
                proxy_hint="  Добавьте в config.yaml маркировку трафика глобально либо в каждое исходящее подключение"
            fi
        fi

        log_warning_terminal "
  Для проксирования трафика Entware требуется его маркировка
  В конфигурации ${yellow}$name_client${reset} параметр ${green}$mark_msg: 255${reset} прописан не везде$error_details

$proxy_hint

  Проксирование трафика Entware ${red}отключено${reset}
"
        proxy_router="off"
    fi

    return 0
}

load_user_ipset_family() {
    set_name="$1"
    family="$2"
    addr_regex="$3"

    ipset create "$set_name" hash:net family "$family" -exist
    ipset flush "$set_name"
    sed -e 's/\r$//' -e 's/#.*//' -e '/^[[:space:]]*$/d' "$file_ip_exclude" |
    grep -Eo "$addr_regex" |
    awk -v s="$set_name" '{print "add "s" "$1}' | ipset restore -exist
}

# Функция загрузки пользовательских исключений в ipset
load_user_ipset() {
    [ ! -f "$file_ip_exclude" ] && return
    [ "$iptables_supported" = "true" ] && load_user_ipset_family user_exclude inet '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?'
    [ "$ip6tables_supported" = "true" ] && load_user_ipset_family user_exclude6 inet6 '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}(/[0-9]{1,3})?'
}

# Функция чтения пользовательских портов из файлов
read_ports_from_file() {
    file_ports="$1"
    [ -f "$file_ports" ] || return

    sed -e 's/\r$//' -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$file_ports"
}

# Функция обработки, валидации и нормализации списка портов
validate_and_clean_ports() {
    input_ports="$1"
    mandatory_ports="$2"
    [ -z "$input_ports" ] && [ -z "$mandatory_ports" ] && return 1

    echo "${mandatory_ports}${mandatory_ports:+,}${input_ports}" | tr ',' '\n' | awk '
        function is_valid(p) {
            return p ~ /^[0-9]+$/ && p > 0 && p <= 65535
        }
        {
            gsub(/[[:space:]]/, "", $0)
            gsub(/-/, ":", $0)
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

                    if (start <= end) {
                        print start ":" end
                    }
                }
            }
        }
    ' | sort -n -u | tr '\n' ',' | sed 's/,$//'
}

# Функция обработки пользовательских портов
process_user_ports() {
    raw_donor=$(read_ports_from_file "$file_port_proxying")

    if [ -n "$raw_donor" ]; then
        port_donor=$(validate_and_clean_ports "$raw_donor" "80,443")
    else
        port_donor=""
    fi

    port_exclude=$(validate_and_clean_ports "$(read_ports_from_file "$file_port_exclude")")

    if [ -n "$port_donor" ] && [ -n "$port_exclude" ]; then
        log_warning_terminal "
  Заданы и порты проксирования, и порты исключения
  Прокси будет запущен на портах проксирования, порты исключения игнорируются
"
        port_exclude=""
    fi
}

# Функция нормализации сторонних политик
process_custom_mark() {
    [ -z "$custom_mark" ] && return

    clean_mark=""
    for mark in $(echo "$custom_mark" | tr ',' ' '); do
        val="${mark#0x}"
        if echo "$val" | grep -Eq '^[0-9a-fA-F]+$'; then
            clean_mark="$clean_mark 0x$val"
        fi
    done

    custom_mark="${clean_mark# }"
}

# Проверка статуса прокси-клиента
proxy_status() { pidof "$name_client" >/dev/null; }

# Поиск конфигураций DNS
check_dns_config() {
    [ "$proxy_dns" != "on" ] && echo "false" && return

    if [ "$name_client" = "xray" ]; then
        for file in "$directory_xray_config"/*.json; do
            [ -f "$file" ] || continue
            if strip_json_comments "$file" | jq -e '.dns.servers? != null' >/dev/null 2>&1; then
                echo "true"
                return
            fi
        done
    elif [ "$name_client" = "mihomo" ]; then
        if [ -f "$mihomo_config" ] && yq -e '.dns.enable == true' "$mihomo_config" >/dev/null 2>&1; then
            echo "true"
            return
        fi
    fi

    echo "false"
    return
}
file_dns=$(check_dns_config)

is_module_loaded() {
    lsmod | awk '{print $1}' | grep -qx "$1"
}

# Загрузка модулей
load_modules() {
    module="$1"
    name="${module%.ko}"

    if ! is_module_loaded "$name"; then
        for dir in "$directory_os_modules" "$directory_user_modules"; do
            if [ -f "$dir/$module" ]; then
                insmod "$dir/$module" >/dev/null 2>&1 && return
            fi
        done
    fi
}

# Обработка модулей и портов
get_modules() {
    load_modules xt_comment.ko
    load_modules xt_TPROXY.ko
    load_modules xt_socket.ko
    load_modules xt_multiport.ko
    load_modules xt_dscp.ko

    if ! is_module_loaded xt_comment; then
        log_error_router "Модуль xt_comment не загружен"
        log_error_terminal "
  Модуль '${light_blue}xt_comment${reset}' не загружен
  Невозможно запустить XKeen без него
  Установите компонент роутера '${yellow}Модули ядра подсистемы Netfilter${reset}'
"
    fi

    if [ "$mode_proxy" = "TProxy" ] || [ "$mode_proxy" = "Hybrid" ]; then
        for module in xt_TPROXY.ko xt_socket.ko; do
            if ! is_module_loaded "${module%.ko}"; then
                proxy_stop
                log_error_router "Модуль ${module} не загружен"
                log_error_terminal "
  Модуль '${light_blue}${module}${reset}' не загружен
  Невозможно запустить XKeen в режиме ${mode_proxy} без него
  Установите компонент роутера '${yellow}Модули ядра подсистемы Netfilter${reset}'
"
            fi
        done
    fi

    if [ -n "$port_donor" ] || [ -n "$port_exclude" ]; then
        if ! is_module_loaded xt_multiport; then
            log_warning_router "Модуль xt_multiport не загружен"
            log_warning_terminal "
  Модуль '${light_blue}xt_multiport${reset}' не загружен
  Невозможно использовать выбранные порты без него
  Установите компонент роутера '${yellow}Модули ядра подсистемы Netfilter${reset}'

  Прокси будет запущен на всех портах
"
            port_donor=""
            port_exclude=""
        fi
    fi

    if [ -n "$dscp_exclude" ] || [ -n "$dscp_proxy" ]; then
        if ! is_module_loaded xt_dscp; then
            log_warning_router "Модуль xt_dscp не загружен"
            log_warning_terminal "
  Модуль '${light_blue}xt_dscp${reset}' не загружен
  Работа с DSCP-метками невозможна
  Установите компонент роутера '${yellow}Модули ядра подсистемы Netfilter${reset}'
"
            dscp_exclude=""
            dscp_proxy=""
        fi
    fi
}

# Получение transparent inbound'ов Xray
get_xray_transparent_inbounds() {
    for file in "$directory_xray_config"/*.json; do
        [ -f "$file" ] || continue

        strip_json_comments "$file" |
        jq -r --arg file "$file" '
            .inbounds[]? |
            select(
                (.protocol == "dokodemo-door" or .protocol == "tunnel") and
                ((.settings.followRedirect? // false) == true)
            ) |
            (.streamSettings.sockopt.tproxy? // "") as $tproxy |
            select($tproxy == "" or $tproxy == "redirect" or $tproxy == "tproxy") |
            [
                (if $tproxy == "tproxy" then "tproxy" else "redirect" end),
                (.port // ""),
                (.settings.network // ""),
                (.tag // ""),
                $file
            ] | @tsv
        ' 2>/dev/null
    done
}

get_xray_port_by_mode() {
    mode="$1"
    port=$(
        get_xray_transparent_inbounds |
        awk -F '\t' -v mode="$mode" '
            $1 == mode && $2 != "" {
                print $2
                exit
            }
        '
    )

    echo "$port"
}

get_xray_network_by_mode() {
    mode="$1"
    network=$(
        get_xray_transparent_inbounds |
        awk -F '\t' -v mode="$mode" '
            function add_networks(value, count, i, item) {
                gsub(/,/, " ", value)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                if (value == "") {
                    return
                }

                count = split(value, items, /[[:space:]]+/)
                for (i = 1; i <= count; i++) {
                    item = items[i]
                    if (item != "" && !seen[item]++) {
                        order[++order_count] = item
                    }
                }
            }

            $1 == mode {
                add_networks($3)
            }

            END {
                for (i = 1; i <= order_count; i++) {
                    printf "%s%s", order[i], (i < order_count ? " " : "")
                }
            }
        '
    )

    echo "$network"
}

# Получение порта для Redirect
get_port_redirect() {
    if [ "$name_client" = "mihomo" ]; then
        port=$(yq eval '.redir-port // ""' "$mihomo_config" 2>/dev/null)
        [ -n "$port" ] && echo "$port" && return 0
    else
        port=$(get_xray_port_by_mode "redirect")
        [ -n "$port" ] && echo "$port" && return 0
    fi

    echo ""
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
        port=$(get_xray_port_by_mode "tproxy")
        [ -n "$port" ] && echo "$port" && return 0
    fi

    echo ""
}

# Получение сети для Redirect
get_network_redirect() {
    if [ "$name_client" = "mihomo" ]; then
        [ -n "$port_redirect" ] && echo "tcp" && return 0
        echo "" && return 0
    else
        network=$(get_xray_network_by_mode "redirect")
        [ -n "$network" ] && echo "$network" && return 0
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
        network=$(get_xray_network_by_mode "tproxy")
        [ -n "$network" ] && echo "$network" && return 0
        echo "" && return 0
    fi
}

# Получение портов исключения из статических пробросов
get_api_exclude_ports() {
    api_redir_result=""

    if [ -n "$api_static_json" ]; then
        api_redir_result=$(echo "$api_static_json" | jq -r '
          [
            .[] | 
            select(.disable != true) | 
            if has("end-port") then 
              "\(.port):\(.["end-port"])" 
            else 
              .port 
            end |
            select(. != "80" and . != "443")
          ] | 
          sort | 
          join(",")')
    fi

    echo "$api_redir_result"
}


# Получение исключенных портов
get_port_exclude() {
    port_exclude_redirect=""
    port_exclude_result=""

    port_exclude_redirect=$(get_api_exclude_ports)

    if [ -n "$port_exclude" ]; then
        if [ -n "$port_exclude_redirect" ]; then
            port_exclude_result="$port_exclude,$port_exclude_redirect"
        else
            port_exclude_result="$port_exclude"
        fi
    else
        port_exclude_result="$port_exclude_redirect"
    fi

    port_exclude_result=$(printf '%s\n' "$port_exclude_result" | tr -dc '0-9,:' | tr -s ',' | sed 's/^,//; s/,$//')
    echo "$port_exclude_result"
}

# Получение исключений IPv4
get_exclude_ip4() {
    [ "$iptables_supported" != "true" ] && return

    # Получаем провайдерский IPv4
    ipv4_eth=$(ip route get 195.208.4.1 2>/dev/null | grep -o 'src [0-9.]\+' | awk '{print $2}' ||
               ip route get 77.88.8.8 2>/dev/null | grep -o 'src [0-9.]\+' | awk '{print $2}')
    [ -n "$ipv4_eth" ] && ipv4_eth="${ipv4_eth}/32"
    echo "${ipv4_eth} ${ipv4_exclude}" | tr ' ' '\n' | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/^ //; s/ $//'
}

# Получение исключений IPv6
get_exclude_ip6() {
    [ "$ip6tables_supported" != "true" ] && return

    # Получаем провайдерский IPv6
    ipv6_eth=$(ip -6 route get 2a0c:a9c7:8::1 2>/dev/null | awk -F 'src ' '{print $2}' | awk '{print $1}' ||
               ip -6 route get 2a02:6b8::feed:0ff 2>/dev/null | awk -F 'src ' '{print $2}' | awk '{print $1}')
    [ -n "$ipv6_eth" ] && ipv6_eth="${ipv6_eth}/128"
    echo "${ipv6_eth} ${ipv6_exclude}" | tr ' ' '\n' | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/^ //; s/ $//'
}

# Получение метки политики
get_policy_mark() {
    if [ -n "$api_policy_json" ]; then
        policy_mark=$(echo "$api_policy_json" | jq -r --arg pname "$name_policy" '.[] | select(.description | ascii_downcase == ($pname | ascii_downcase)) | .mark' 2>/dev/null)
    fi

    if [ -n "$policy_mark" ]; then
        echo "0x${policy_mark}"
    else
        echo ""
    fi
}

# Получение меток политик "Без доступа в интернет"
get_no_internet_marks() {
    [ -z "$api_policy_json" ] && return
    _result=""
    _marks=$(echo "$api_policy_json" | jq -r '.[].mark // empty' 2>/dev/null)
    for _mark in $_marks; do
        [ -z "$_mark" ] && continue
        _table=$(ip rule show 2>/dev/null | awk -v m="0x$_mark" '$0 ~ m && /lookup/ && !/blackhole/ {print $NF}' | head -n1)
        [ -z "$_table" ] && continue
        _default=$(ip -4 route show table "$_table" 2>/dev/null | grep '^default')
        if [ -z "$_default" ] || printf '%s\n' "$_default" | grep -qE 'unreachable|blackhole|prohibit'; then
            _result="$_result 0x$_mark"
        fi
    done
    printf '%s\n' "${_result# }"
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
  В файле '${yellow}xkeen.json${reset}' найдена политика с именем '${red}${conflict}${reset}'
  Это имя зарезервировано основной службой XKeen

  Переименуйте пользовательскую политику в json-файле
  Запуск ${yellow}$name_client${reset} ${red}отменен${reset}
"
        fi
    fi
}

# Получаем порты пользовательских политик
resolve_user_policies() {
    api_exclude_ports=""
    api_exclude_ports=$(get_api_exclude_ports)

    get_user_policies | while IFS='|' read -r pname pports; do
        if [ -n "$api_policy_json" ]; then
            mark=$(echo "$api_policy_json" | jq -r --arg pname "$pname" '.[] | select(.description | ascii_downcase == ($pname | ascii_downcase)) | .mark' 2>/dev/null | head -n 1)
        fi

        [ -z "$mark" ] && continue

        if [ -z "$pports" ]; then
            # Порты не указаны -> режим "all" (все порты)
            if [ -n "$api_exclude_ports" ]; then
                mode="exclude"
                clean_ports="$api_exclude_ports"
            else
                mode="all"
                clean_ports=""
            fi
        else
            case "$pports" in
                !*)
                    mode="exclude"
                    ports="${pports#!}"

                    if [ -n "$api_exclude_ports" ]; then
                        if [ -n "$ports" ]; then
                            ports="$ports,$api_exclude_ports"
                        else
                            ports="$api_exclude_ports"
                        fi
                    fi
                    ;;
                *)
                    mode="include"
                    ports="$pports"
                    ;;
            esac

            if [ "$file_dns" = "true" ] && [ "$proxy_dns" = "on" ] && [ "$mode" = "include" ]; then
                echo "$ports" | tr ',' '\n' | grep -q '^53$' || ports="53,$ports"
            fi

            clean_ports=$(validate_and_clean_ports "$ports")
            [ -z "$clean_ports" ] && continue
        fi

        echo "${pname}|${mark}|${mode}|${clean_ports}"
    done
}

# Получение режима прокси-клиента
get_mode_proxy() {
    if [ -n "$port_redirect" ] && [ -n "$port_tproxy" ]; then
        mode_proxy="Hybrid"
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
name_chain="$name_chain"
port_redirect="$port_redirect"
port_tproxy="$port_tproxy"
port_donor="$port_donor"
port_exclude="$port_exclude"
policy_mark="$policy_mark"
comment_tag="$comment_tag"
comment="$comment"
custom_mark="$custom_mark"
dscp_exclude="$dscp_exclude"
dscp_proxy="$dscp_proxy"
user_policies="$user_policies"
table_redirect="$table_redirect"
table_tproxy="$table_tproxy"
table_mark="$table_mark"
table_id="$table_id"
file_dns="$file_dns"
proxy_dns="$proxy_dns"
proxy_router="$proxy_router"
directory_os_modules="$directory_os_modules"
directory_user_modules="$directory_user_modules"
directory_configs_app="$directory_configs_app"
directory_xray_config="$directory_xray_config"
directory_xray_asset="$directory_xray_asset"
iptables_supported="$iptables_supported"
ip6tables_supported="$ip6tables_supported"
arm64_fd="$arm64_fd"
other_fd="$other_fd"
aghfix="$aghfix"
no_internet_marks="$no_internet_marks"

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
            if [ "\$file_dns" = "true" ] && [ "\$proxy_dns" = "on" ] && [ "\$chain" != "\${name_chain}_out" ]; then
                case "\$exclude" in
                    10.0.0.0/8|172.16.0.0/12|192.168.0.0/16|fd00::/8|fe80::/10)
                    if [ "\$table" = "mangle" ] && [ "\$mode_proxy" = "Hybrid" ]; then
                        ipt -A "\$chain" -d "\$exclude" -p tcp --dport 53 \$comment -j RETURN >/dev/null 2>&1
                        ipt -A "\$chain" -d "\$exclude" -p udp ! --dport 53 \$comment -j RETURN >/dev/null 2>&1
                    elif [ "\$table" = "nat" ] && [ "\$mode_proxy" = "Hybrid" ]; then
                        ipt -A "\$chain" -d "\$exclude" -p tcp ! --dport 53 \$comment -j RETURN >/dev/null 2>&1
                        ipt -A "\$chain" -d "\$exclude" -p udp --dport 53 \$comment -j RETURN >/dev/null 2>&1
                    elif [ "\$table" = "mangle" ] && [ "\$mode_proxy" = "TProxy" ]; then
                        ipt -A "\$chain" -d "\$exclude" -p tcp ! --dport 53 \$comment -j RETURN >/dev/null 2>&1
                        ipt -A "\$chain" -d "\$exclude" -p udp ! --dport 53 \$comment -j RETURN >/dev/null 2>&1
                    fi
                    ;;
                esac
            else
                ipt -A "\$chain" -d "\$exclude" \$comment -j RETURN >/dev/null 2>&1
            fi
        done
    }

    add_ipset_exclude() {
        base_set="\$1"
        set_type="\${2:-hash:net}"

        if [ "\$family" = "ip6tables" ]; then
            set_name="\${base_set}6"
            ipset_family="inet6"
        else
            set_name="\$base_set"
            ipset_family="inet"
        fi

        ipset create "\$set_name" "\$set_type" family "\$ipset_family" -exist || return

        ipt -C "\$chain" -m set --match-set "\$set_name" dst \$comment -j RETURN >/dev/null 2>&1 ||
        ipt -I "\$chain" 1 -m set --match-set "\$set_name" dst \$comment -j RETURN >/dev/null 2>&1
    }

    # Добавление правил iptables
    add_ipt_rule() {
        family="\$1"
        table="\$2"
        chain="\$3"
        shift 3
        [ "\$family" = "iptables" ] && [ "\$iptables_supported" = "false" ] && return
        [ "\$family" = "ip6tables" ] && [ "\$ip6tables_supported" = "false" ] && return

        if ! "\$family" -w -t "\$table" -nL "\$chain" >/dev/null 2>&1; then
            "\$family" -w -t "\$table" -N "\$chain" || exit 0

            add_exclude_rules "\$chain"

            if [ "\$table" = "\$table_tproxy" ]; then
                if [ "\$mode_proxy" = "Hybrid" ]; then
                    set -- -p udp -m conntrack --ctstate ESTABLISHED,RELATED \$comment -j CONNMARK --restore-mark
                else
                    set -- -m conntrack --ctstate ESTABLISHED,RELATED \$comment -j CONNMARK --restore-mark
                fi
                ipt -C "\$chain" "\$@" >/dev/null 2>&1 || ipt -I "\$chain" 1 "\$@" >/dev/null 2>&1
            fi

            case "\$mode_proxy" in
                Hybrid)
                    if [ "\$table" = "\$table_redirect" ]; then
                        ipt -I "\$chain" 1 -m conntrack --ctstate DNAT \$comment -j RETURN >/dev/null 2>&1
                        add_ipset_exclude ext_exclude hash:ip
                        add_ipset_exclude geo_exclude hash:net
                        add_ipset_exclude user_exclude hash:net
                        ipt -A "\$chain" -p tcp \$comment -j REDIRECT --to-port "\$port_redirect" >/dev/null 2>&1
                    else
                        ipt -I "\$chain" 1 -m conntrack --ctstate DNAT \$comment -j RETURN >/dev/null 2>&1
                        add_ipset_exclude ext_exclude hash:ip
                        add_ipset_exclude geo_exclude hash:net
                        add_ipset_exclude user_exclude hash:net
                        ipt -A "\$chain" -p udp -m socket --transparent \$comment -j MARK --set-mark "\$table_mark" >/dev/null 2>&1
                        ipt -A "\$chain" -p udp -m mark ! --mark 0 \$comment -j CONNMARK --save-mark >/dev/null 2>&1
                        ipt -A "\$chain" -p udp \$comment -j TPROXY --on-ip "\$proxy_ip" --on-port "\$port_tproxy" --tproxy-mark "\$table_mark" >/dev/null 2>&1
                    fi
                    ;;
                TProxy)
                    ipt -C "\$chain" -m conntrack --ctstate DNAT \$comment -j RETURN >/dev/null 2>&1 ||
                    ipt -I "\$chain" 1 -m conntrack --ctstate DNAT \$comment -j RETURN >/dev/null 2>&1
                    for net in \$network_tproxy; do
                        add_ipset_exclude ext_exclude hash:ip
                        add_ipset_exclude geo_exclude hash:net
                        add_ipset_exclude user_exclude hash:net
                        ipt -A "\$chain" -p "\$net" -m socket --transparent \$comment -j MARK --set-mark "\$table_mark" >/dev/null 2>&1
                        ipt -A "\$chain" -p "\$net" -m mark ! --mark 0 \$comment -j CONNMARK --save-mark >/dev/null 2>&1
                        ipt -A "\$chain" -p "\$net" \$comment -j TPROXY --on-ip "\$proxy_ip" --on-port "\$port_tproxy" --tproxy-mark "\$table_mark" >/dev/null 2>&1
                    done
                    ;;
                Redirect)
                    ipt -C "\$chain" -m conntrack --ctstate DNAT \$comment -j RETURN >/dev/null 2>&1 ||
                    ipt -I "\$chain" 1 -m conntrack --ctstate DNAT \$comment -j RETURN >/dev/null 2>&1
                    add_ipset_exclude ext_exclude hash:ip
                    add_ipset_exclude geo_exclude hash:net
                    add_ipset_exclude user_exclude hash:net
                    for net in \$network_redirect; do
                        ipt -A "\$chain" -p "\$net" \$comment -j REDIRECT --to-port "\$port_redirect" >/dev/null 2>&1
                    done
                    ;;
                *) exit 0 ;;
            esac

            if [ -n "\$dscp_exclude" ]; then
                for dscp in "\$dscp_exclude"; do
                    ipt -I "\$chain" -m dscp --dscp "\$dscp" \$comment -j RETURN >/dev/null 2>&1
                done
            fi
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
            if [ "\$ip_version" = "6" ] && ! ip -6 route show default 2>/dev/null | grep -q .; then
                return 0
            fi
            if [ "\$source_table" = "main" ]; then
                ip -"\$ip_version" route show default 2>/dev/null | grep -q '^default'
            else
                ip -"\$ip_version" route show table all 2>/dev/null | grep -E "^[[:space:]]*default .* table \$policy_table([[:space:]]|$)" | grep -vq 'unreachable' >/dev/null
            fi
        }

        attempts=0
        max_attempts=4
        until check_default; do
            attempts=\$((attempts + 1))
            if [ "\$attempts" -ge "\$max_attempts" ]; then
                [ "\$ip_version" = "4" ] && touch "/tmp/noinet"
                return 1
            fi
            sleep 1
        done
        [ "\$ip_version" = "4" ] && rm -f "/tmp/noinet"

        ip -"\$ip_version" rule del fwmark "\$table_mark" lookup "\$table_id" >/dev/null 2>&1 || true
        ip -"\$ip_version" route flush table "\$table_id" >/dev/null 2>&1 || true
        ip -"\$ip_version" route add local default dev lo table "\$table_id" >/dev/null 2>&1 || true
        ip -"\$ip_version" rule add fwmark "\$table_mark" lookup "\$table_id" >/dev/null 2>&1 || true

        # Копируем маршруты
        ip -"\$ip_version" route show table "\$source_table" 2>/dev/null | while read -r route_line; do
            case "\$route_line" in
                default*|unreachable*|blackhole*) continue ;;
                *) ip -"\$ip_version" route add table "\$table_id" "\$route_line" >/dev/null 2>&1 || true ;;
            esac
        done
        return 0
    }

    flush_xkeen_rules() {
        ipt -S PREROUTING 2>/dev/null | grep -E -- "\$comment_tag" | sed 's/^-A /-D /' | while IFS= read -r _r; do
            [ -n "$_r" ] && ipt $_r >/dev/null 2>&1
        done
    }

    # Создание множественных правил multiport
    add_multiport_rules() {
        family="\$1"
        table="\$2"
        net="\$3"
        mark="\$4"
        ports="\$5"
        target="\$6"

        [ -z "\$ports" ] && return

        num_ports=\$(echo "\$ports" | tr ',' '\n' | wc -l)
        i=1
        while [ "\$i" -le "\$num_ports" ]; do
            end=\$((i + 6))
            chunk=\$(echo "\$ports" | tr ',' '\n' | sed -n "\${i},\${end}p" | tr '\n' ',' | sed 's/,$//')
            [ -z "\$chunk" ] && break
            if [ -n "\$mark" ]; then
                set -- -m connmark --mark "\$mark" -m conntrack ! --ctstate INVALID -p "\$net" -m multiport --dports "\$chunk" \$comment -j "\$target"
            else
                set -- -m conntrack ! --ctstate INVALID -p "\$net" -m multiport --dports "\$chunk" \$comment -j "\$target"
            fi
            ipt -C PREROUTING "\$@" >/dev/null 2>&1 || ipt -A PREROUTING "\$@" >/dev/null 2>&1
            i=\$((i + 7))
        done
    }

    # Добавление цепочек PREROUTING
    add_prerouting() {
        family="\$1"
        table="\$2"

        flush_xkeen_rules

        for _nim in \$no_internet_marks; do
            set -- -m connmark --mark "\$_nim" -m conntrack ! --ctstate INVALID \$comment -j RETURN
            ipt -C PREROUTING "\$@" >/dev/null 2>&1 || ipt -A PREROUTING "\$@" >/dev/null 2>&1
        done

        for net in \$networks; do
            if [ "\$mode_proxy" = "Hybrid" ]; then
                [ "\$table" = "nat"    ] && [ "\$net" != "tcp" ] && continue
                [ "\$table" = "mangle" ] && [ "\$net" != "udp" ] && continue
            fi

            if [ "\$mode_proxy" = "TProxy" ]; then
                proto_match=""
            else
                proto_match="-p \$net"
            fi

            for dscp in \$dscp_proxy; do
                set -- -m conntrack ! --ctstate INVALID \$proto_match -m dscp --dscp "\$dscp" \$comment -j "\$name_chain"
                ipt -C PREROUTING "\$@" >/dev/null 2>&1 || ipt -A PREROUTING "\$@" >/dev/null 2>&1
            done

            if [ "\$proxy_router" = "on" ]; then
                set -- -i lo -m mark --mark "\$table_mark" \$proto_match \$comment -j "\$name_chain"
                ipt -C PREROUTING "\$@" >/dev/null 2>&1 || ipt -A PREROUTING "\$@" >/dev/null 2>&1
            fi

            # Пользовательские политики из xkeen.json
            echo "\$user_policies" | while IFS='|' read -r pname pmark pmode pports; do
                [ -z "\$pmark" ] && continue

                pmark=\$(echo "\$pmark" | tr -d ' \r\n')
                pmode=\$(echo "\$pmode" | tr -d ' \r\n')
                pports=\$(echo "\$pports" | tr -d ' \r\n')

                if [ "\$pmode" = "all" ]; then
                    set -- -m connmark --mark 0x"\$pmark" -m conntrack ! --ctstate INVALID \$comment -j "\$name_chain"
                    ipt -C PREROUTING "\$@" >/dev/null 2>&1 || ipt -A PREROUTING "\$@" >/dev/null 2>&1
                elif [ "\$pmode" = "include" ]; then
                    add_multiport_rules "\$family" "\$table" "\$net" "0x\$pmark" "\$pports" "\$name_chain"
                elif [ "\$pmode" = "exclude" ]; then
                    add_multiport_rules "\$family" "\$table" "\$net" "0x\$pmark" "\$pports" "RETURN"
                    set -- -m connmark --mark 0x"\$pmark" -m conntrack ! --ctstate INVALID -p "\$net" \$comment -j "\$name_chain"
                    ipt -C PREROUTING "\$@" >/dev/null 2>&1 || ipt -A PREROUTING "\$@" >/dev/null 2>&1
                fi
            done

            # Политика xkeen (стандартная)
            if [ -n "\$policy_mark" ]; then
                # заданы порты проксирования
                if [ -n "\$port_donor" ]; then
                    add_multiport_rules "\$family" "\$table" "\$net" "\$policy_mark" "\$port_donor" "\$name_chain"
                # заданы порты исключения
                elif [ -n "\$port_exclude" ]; then
                    add_multiport_rules "\$family" "\$table" "\$net" "\$policy_mark" "\$port_exclude" "RETURN"
                    set -- -m connmark --mark "\$policy_mark" -m conntrack ! --ctstate INVALID -p "\$net" \$comment -j "\$name_chain"
                    ipt -C PREROUTING "\$@" >/dev/null 2>&1 || ipt -A PREROUTING "\$@" >/dev/null 2>&1
                else
                    # Политика xkeen, когда порты не указаны (проксирование на всех портах)
                    set -- -m connmark --mark "\$policy_mark" -m conntrack ! --ctstate INVALID \$comment -j "\$name_chain"
                    ipt -C PREROUTING "\$@" >/dev/null 2>&1 || ipt -A PREROUTING "\$@" >/dev/null 2>&1
                fi
            # НЕТ политики xkeen
            else
                # заданы порты проксирования
                if [ -n "\$port_donor" ]; then
                    add_multiport_rules "\$family" "\$table" "\$net" "" "\$port_donor" "\$name_chain"
                # заданы порты исключения
                elif [ -n "\$port_exclude" ]; then
                    add_multiport_rules "\$family" "\$table" "\$net" "" "\$port_exclude" "RETURN"
                    set -- -m conntrack ! --ctstate INVALID -p "\$net" \$comment -j "\$name_chain"
                    ipt -C PREROUTING "\$@" >/dev/null 2>&1 || ipt -A PREROUTING "\$@" >/dev/null 2>&1
                # Если нет ни xkeen, ни пользовательских политик -> перехватываем всё
                else
                    set -- -m conntrack ! --ctstate INVALID \$comment -j "\$name_chain"
                    ipt -C PREROUTING "\$@" >/dev/null 2>&1 || ipt -A PREROUTING "\$@" >/dev/null 2>&1
                fi
            fi
        done
    }

    # Добавление цепочек для проксирования трафика Entware
    add_output() {
        family="\$1"
        table="\$2"

        [ "\$proxy_router" != "on" ] && return

        out_chain="\${name_chain}_out"

        if ! "\$family" -w -t "\$table" -nL "\$out_chain" >/dev/null 2>&1; then
            "\$family" -w -t "\$table" -N "\$out_chain" || return

            orig_chain="\$chain"
            chain="\$out_chain"

            ipt -A "\$out_chain" -o lo \$comment -j RETURN >/dev/null 2>&1
            ipt -A "\$out_chain" -m mark --mark 255 \$comment -j RETURN >/dev/null 2>&1

            add_exclude_rules "\$out_chain"

            add_ipset_exclude ext_exclude hash:ip
            add_ipset_exclude geo_exclude hash:net
            add_ipset_exclude user_exclude hash:net

            chain="\$orig_chain"
        fi

        for net in \$networks; do
            if [ "\$mode_proxy" = "Hybrid" ]; then
                [ "\$table" = "nat"    ] && [ "\$net" != "tcp" ] && continue
                [ "\$table" = "mangle" ] && [ "\$net" != "udp" ] && continue
            fi

            if [ "\$mode_proxy" = "TProxy" ]; then
                proto_match=""
            else
                proto_match="-p \$net"
            fi

            set -- -m conntrack ! --ctstate INVALID \$proto_match \$comment -j "\$out_chain"
            ipt -C OUTPUT "\$@" >/dev/null 2>&1 || ipt -A OUTPUT "\$@" >/dev/null 2>&1

            if [ "\$table" = "\$table_redirect" ]; then
                set -- -p "\$net" \$comment -j REDIRECT --to-port "\$port_redirect"
                ipt -C "\$out_chain" "\$@" >/dev/null 2>&1 || ipt -A "\$out_chain" "\$@" >/dev/null 2>&1
            elif [ "\$table" = "\$table_tproxy" ]; then
                set -- -p "\$net" \$comment -j MARK --set-mark "\$table_mark"
                ipt -C "\$out_chain" "\$@" >/dev/null 2>&1 || ipt -A "\$out_chain" "\$@" >/dev/null 2>&1
            fi
        done
    }

    dns_redir() {
        family="\$1"
        table="nat"

        [ "\$aghfix" != "on" ] && return
        [ "\$file_dns" = "true" ] && [ "\$proxy_dns" = "on" ] && return

        all_marks=""
        [ -n "\$policy_mark" ] && all_marks="\$policy_mark"

        [ -n "\$custom_mark" ] && all_marks="\$custom_mark \$all_marks"

        if [ -n "\$user_policies" ]; then
            user_marks=\$(echo "\$user_policies" | awk -F'|' '{if (\$2 != "") print "0x"\$2}')
            all_marks="\$all_marks \$user_marks"
        fi

        for mark in \$all_marks; do
            mark=\$(echo "\$mark" | tr -d ' \r\n')
            [ -z "\$mark" ] && continue

            for proto in udp tcp; do
                set -- -p "\$proto" -m mark --mark "\$mark" -m pkttype --pkt-type unicast -m "\$proto" --dport 53 \$comment -j REDIRECT --to-ports 53
                ipt -C _NDM_HOTSPOT_DNSREDIR "\$@" >/dev/null 2>&1 || ipt -I _NDM_HOTSPOT_DNSREDIR "\$@" >/dev/null 2>&1
            done
        done
    }

    if [ -n "\$port_donor" ] || [ -n "\$port_exclude" ]; then
        [ "\$file_dns" = "true" ] && [ "\$proxy_dns" = "on" ] && [ -n "\$port_donor" ] && port_donor="53,\$port_donor"
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
                add_ipt_rule "\$family" "\$table" "\$name_chain"
                add_prerouting "\$family" "\$table"
                add_output "\$family" "\$table"
            done
        elif [ -z "\$port_redirect" ] && [ -n "\$port_tproxy" ]; then
            table="\$table_tproxy"
            add_ipt_rule "\$family" "\$table" "\$name_chain"
            add_prerouting "\$family" "\$table"
            add_output "\$family" "\$table"
        elif [ -n "\$port_redirect" ] && [ -z "\$port_tproxy" ]; then
            table="\$table_redirect"
            add_ipt_rule "\$family" "\$table" "\$name_chain"
            add_prerouting "\$family" "\$table"
            add_output "\$family" "\$table"
        fi

        dns_redir "\$family"
    done
else
    [ -f "/tmp/xkeen_starting.lock" ] && exit 0
    touch "/tmp/xkeen_starting.lock"
    . "/opt/sbin/.xkeen/01_info/03_info_cpu.sh"
    status_file="/opt/lib/opkg/status"
    info_cpu

    fd_limit="\$other_fd"
    [ "\$architecture" = "arm64-v8a" ] && fd_limit="\$arm64_fd"
    ulimit -SHn "\$fd_limit"

    case "\$name_client" in
        xray)
            export XRAY_LOCATION_CONFDIR="\$directory_xray_config"
            export XRAY_LOCATION_ASSET="\$directory_xray_asset"
            "\$name_client" run >/dev/null 2>&1 &
        ;;
        mihomo)
            export CLASH_HOME_DIR="\$directory_configs_app"
            "\$name_client" >/dev/null 2>&1 &
        ;;
    esac
    sleep 5
    rm -f "/tmp/xkeen_starting.lock"
    if pidof "\$name_client" >/dev/null; then
        restart_script "\$@"
    else
        exit 1
    fi
fi
EOL

    chmod +x "$file_netfilter_hook"
    sh "$file_netfilter_hook"
}

# Удаление правил Iptables
clean_firewall() {
    [ -f "$file_netfilter_hook" ] && : > "$file_netfilter_hook"

    get_ipver_support

    for family in iptables ip6tables; do
        [ "$family" = "iptables" ] && [ "$iptables_supported" != "true" ] && continue
        [ "$family" = "ip6tables" ] && [ "$ip6tables_supported" != "true" ] && continue

        if "$family" -w -t nat -nL _NDM_HOTSPOT_DNSREDIR >/dev/null 2>&1; then
            "$family" -w -t nat -S _NDM_HOTSPOT_DNSREDIR | grep -E -- "$comment_tag" | sed 's/^-A /-D /' | while IFS= read -r rule; do
                [ -n "$rule" ] && "$family" -w -t nat $rule >/dev/null 2>&1
            done
        fi
    done

    clean_run() {
        family="$1"
        table="$2"
        name_chain="$3"

        for sys_chain in PREROUTING OUTPUT; do
            "$family" -w -t "$table" -S "$sys_chain" 2>/dev/null | grep -E -- "$comment_tag" | sed 's/^-A /-D /' | while IFS= read -r rule; do
                [ -n "$rule" ] && "$family" -w -t "$table" $rule >/dev/null 2>&1
            done
        done

        if "$family" -w -t "$table" -nL "$name_chain" >/dev/null 2>&1; then
            "$family" -w -t "$table" -F "$name_chain" >/dev/null 2>&1
            "$family" -w -t "$table" -X "$name_chain" >/dev/null 2>&1
        fi

        out_chain="${name_chain}_out"
        if "$family" -w -t "$table" -nL "$out_chain" >/dev/null 2>&1; then
            "$family" -w -t "$table" -F "$out_chain" >/dev/null 2>&1
            "$family" -w -t "$table" -X "$out_chain" >/dev/null 2>&1
        fi
    }

    for family in iptables ip6tables; do
        for chain in nat mangle; do
            clean_run "$family" "$chain" "$name_chain"
        done
    done

    if command -v ip >/dev/null 2>&1; then
        for family in 4 6; do
            while ip -"$family" rule del fwmark "$table_mark" lookup "$table_id" >/dev/null 2>&1; do :; done
            ip -"$family" route flush table "$table_id" >/dev/null 2>&1 || true
        done
    fi

    # Очистка и удаление списков ipset
    if command -v ipset >/dev/null 2>&1; then
        for set in geo_exclude geo_exclude6 user_exclude user_exclude6; do
            ipset flush "$set" >/dev/null 2>&1
            ipset destroy "$set" >/dev/null 2>&1
        done
    fi
}

# Мониторинг файловых дескрипторов
monitor_fd() {
    while true; do
        client_pid=$(pidof "$name_client" | awk '{print $1}')
        if [ -n "$client_pid" ] && [ -d "/proc/$client_pid/fd" ]; then
            limit=$(awk '/Max open files/ {print $4}' "/proc/$client_pid/limits")
            set -- /proc/$client_pid/fd/*
            [ -e "$1" ] || set --
            current=$#
            if [ "$limit" -gt 0 ] && [ "$current" -gt $((limit * 90 / 100)) ]; then
                log_warning_router "$name_client открыл $current из $limit файловых дескрипторов, инициирован перезапуск"
                rm -f "$file_pid_fd"
                fd_out=true
                proxy_stop
                proxy_start "on"
                exit 0
            fi
        fi
        sleep "$delay_fd"
    done
}

load_ipset() {
    set="$1"
    file="$2"
    family="$3"

    ipset create "$set" hash:net family "$family" -exist
    ipset flush "$set"

    [ -f "$file" ] && sed -e 's/\r$//' -e 's/#.*//' -e '/^[[:space:]]*$/d' "$file" | awk '{print "add '"$set"' "$1}' | ipset restore -exist
}

apply_fd_limit() {
    fd_limit="$other_fd"
    [ "$architecture" = "arm64-v8a" ] && fd_limit="$arm64_fd"
    ulimit -SHn "$fd_limit"
}

cleanup_fd_monitor() {
    [ -f "$file_pid_fd" ] || return 0
    kill "$(cat "$file_pid_fd")" 2>/dev/null
    rm -f "$file_pid_fd"
}

missing_files_template='
  '"${light_blue}"'Отсутствуют исполняемые файлы:'"${reset}"'
  '"${yellow}"'%b'"${reset}"'

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
    if [ "$start_manual" = "on" ] || [ "$start_auto" = "on" ]; then
        apply_ipv6_state
        get_ipver_support

        case "$name_client" in
            xray)
                if [ ! -x "$install_dir/xray" ]; then
                    log_error_terminal "$(printf "$missing_files_template" "$install_dir/xray")"
                fi
                ;;
            mihomo)
                if [ ! -x "$install_dir/mihomo" ] || [ ! -x "$install_dir/yq" ]; then
                    missing_files=""
                    [ ! -x "$install_dir/yq" ] && missing_files="$install_dir/yq"
                    [ ! -x "$install_dir/mihomo" ] && missing_files="$install_dir/mihomo\n  $missing_files"
                    log_error_terminal "$(printf "$missing_files_template" "$missing_files")"
                fi
                ;;
        esac

        validate_xkeen_json
        check_policy_name_conflict
        check_xray_backups
        validate_routing_mark
        log_clean
        api_cache_init
        process_user_ports
        process_custom_mark
        port_redirect=$(get_port_redirect)
        network_redirect=$(get_network_redirect)
        port_tproxy=$(get_port_tproxy)
        network_tproxy=$(get_network_tproxy)
        mode_proxy=$(get_mode_proxy)
        if [ "$mode_proxy" != "Other" ]; then
            policy_mark=$(get_policy_mark)
            no_internet_marks=$(get_no_internet_marks)

            if [ -n "$policy_mark" ]; then
                user_policies=$(resolve_user_policies)

                if [ -n "$user_policies" ]; then
                    print_policy_info "yes" "yes"
                else
                    print_policy_info "yes" "no"
                fi
            else
                raw_user_policies=$(get_user_policies)
                ignored_custom="no"

                if [ -n "$raw_user_policies" ]; then
                    ignored_custom="yes"
                fi

                print_policy_info "no" "no" "$ignored_custom"

                user_policies=""
            fi

            networks=$(printf '%s\n' $network_redirect $network_tproxy | tr ',' ' ' | tr -s ' ' '\n' | sort -u | tr '\n' ' ')
            networks=${networks% }

            if [ -n "$policy_mark" ] && [ -z "$port_donor" ]; then
                port_exclude=$(get_port_exclude)
            fi
            if ! proxy_status && { [ -n "$port_donor" ] || [ -n "$port_exclude" ] || [ "$mode_proxy" = "TProxy" ] || [ "$mode_proxy" = "Hybrid" ]; }; then
                get_modules
            fi
            if [ "$mode_proxy" = "TProxy" ]; then
                keenetic_ssl="$(get_keenetic_port)" || {
                    proxy_stop
                    log_error_router "Порт 443 занят сервисами Keenetic"
                    log_error_terminal "
  Необходимый для режима ${light_blue}TProxy${reset} ${red}443 порт занят${reset} сервисами Keenetic

  Освободите его на странице 'Пользователи и доступ' веб-интерфейса роутера
"
                }
            fi
        fi
        if proxy_status; then
            echo -e "  Прокси-клиент уже ${green}запущен${reset}"
            [ "$mode_proxy" != "Other" ] && configure_firewall
            if [ "$start_manual" = "on" ]; then
                log_error_terminal "Не удалось запустить ${yellow}$name_client${reset}, так как он уже запущен"
            else
                log_info_router "Прокси-клиент успешно запущен в режиме $mode_proxy"
            fi
        else
            log_info_router "Инициирован запуск прокси-клиента"
            attempt=1
            . "/opt/sbin/.xkeen/01_info/03_info_cpu.sh"
            status_file="/opt/lib/opkg/status"
            info_cpu
            while [ "$attempt" -le "$start_attempts" ]; do
                case "$name_client" in
                    xray)
                        export XRAY_LOCATION_CONFDIR="$directory_xray_config"
                        export XRAY_LOCATION_ASSET="$directory_xray_asset"
                        find "$directory_xray_config" -maxdepth 1 -name '._*.json' -type f -delete
                        apply_fd_limit
                        if [ -n "$fd_out" ]; then
                            nohup "$name_client" run >/dev/null 2>&1 &
                            unset fd_out
                        else
                            "$name_client" run &
                        fi
                    ;;
                    mihomo)
                        export CLASH_HOME_DIR="$directory_configs_app"
                        apply_fd_limit
                        if [ -n "$fd_out" ]; then
                            nohup "$name_client" >/dev/null 2>&1 &
                            unset fd_out
                        else
                            "$name_client" &
                        fi
                        ;;
                    *) log_error_terminal "Неизвестный прокси-клиент: ${yellow}$name_client${reset}" ;;
                esac
                sleep 2
                if proxy_status; then
                    [ "$mode_proxy" != "Other" ] && configure_firewall
                    [ "$iptables_supported" = "true" ] && [ -f "$ru_exclude_ipv4" ] && load_ipset geo_exclude "$ru_exclude_ipv4" inet
                    [ "$ip6tables_supported" = "true" ] && [ -f "$ru_exclude_ipv6" ] && load_ipset geo_exclude6 "$ru_exclude_ipv6" inet6
                    load_user_ipset
                    echo -e "  Прокси-клиент ${green}запущен${reset} в режиме ${light_blue}${mode_proxy}${reset}"
                    if [ -n "$api_policy_json" ]; then
                        if echo "$api_policy_json" | jq --arg policy "$name_policy" -e 'any(.[]; .description | ascii_downcase == $policy)' > /dev/null; then
                            if [ -e "/tmp/noinet" ]; then
                                echo
                                echo -e "  У политики ${yellow}$name_policy${reset} ${red}нет доступа в интернет${reset}"
                                echo "  Проверьте, установлена ли галка на подключении к провайдеру"
                            fi
                        fi
                    fi
                    [ "$mode_proxy" = "Other" ] && echo -e "  Функция прозрачного прокси ${red}не активна${reset}. Направляйте соединения на ${yellow}${name_client}${reset} вручную"
                    log_info_router "Прокси-клиент успешно запущен в режиме $mode_proxy"
                    if [ "$check_fd" = "on" ]; then
                        cleanup_fd_monitor
                        monitor_fd &
                        echo $! > "$file_pid_fd"
                        log_info_router "Запущен контроль файловых дескрипторов $name_client"
                    fi
                    return 0
                fi
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
        cleanup_fd_monitor
    else
        [ -f "/tmp/xkeen_coldstart.lock" ] || log_info_router "Инициирована остановка прокси-клиента"
        cleanup_fd_monitor
        attempt=1
        while [ "$attempt" -le "$start_attempts" ]; do
            clean_firewall
            killall -q -9 "$name_client"
            sleep 1
            if ! proxy_status; then
                echo -e "  Прокси-клиент ${red}остановлен${reset}"
                [ -f "/tmp/xkeen_coldstart.lock" ] || log_info_router "Прокси-клиент успешно остановлен"
                rm -f "/tmp/xkeen_coldstart.lock"
                return 0
            fi
            attempt=$((attempt + 1))
        done
        echo -e "  Прокси-клиент ${red}не удалось остановить${reset}"
        log_error_terminal "Не удалось остановить прокси-клиент"
    fi
}

# Менеджер команд
case "$1" in
    start)
        ipset create ext_exclude hash:ip family inet -exist
        ipset create ext_exclude6 hash:ip family inet6 -exist
        if [ -z "$2" ]; then
            [ "$start_auto" != "on" ] && exit 0
            log_info_router "Подготовка к запуску прокси-клиента"
            nohup sh -c "sleep $start_delay && $0 restart" >/dev/null 2>&1 &
            touch "/tmp/xkeen_coldstart.lock"
            exit 0
        fi
        proxy_start "$2"
    ;;
    stop) proxy_stop ;;
    status)
        if proxy_status; then
            mode_proxy=$(grep '^mode_proxy=' "$file_netfilter_hook" | awk -F'"' '{print $2}')
            echo -e "  Прокси-клиент ${yellow}$name_client${reset} ${green}запущен${reset} в режиме ${light_blue}$mode_proxy${reset}"
        else
            echo -e "  Прокси-клиент ${red}не запущен${reset}"
        fi
        ;;
    restart) proxy_stop; proxy_start "$2" ;;
    *) echo -e "  Команды: ${green}start${reset} | ${red}stop${reset} | ${yellow}restart${reset} | status" ;;
esac

exit 0