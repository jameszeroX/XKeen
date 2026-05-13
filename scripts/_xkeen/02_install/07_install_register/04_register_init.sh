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

# GID для трафика прокси-ядра — маршрутизация исходящих сокетов xray/mihomo
# в Keenetic-policy WAN (включая резервный). xray/mihomo запускаются с
# UID=0 + GID=$gid_xkeen, iptables OUTPUT mangle помечает их пакеты
# меткой Keenetic policy_mark через `-m owner --gid-owner $gid_xkeen`.
gid_xkeen="23333"
group_xkeen="xkeen"

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
log_info_router() { logger -p notice -t "$name_app" "$1"; }
log_warning_router() { logger -p warning -t "$name_app" "$1"; }
log_error_router() { logger -p error -t "$name_app" "$1"; }

log_info_terminal() { echo -e "\n${green}Информация${reset}: $1" >&2; }
log_warning_terminal() { echo -e "\n${yellow}Предупреждение${reset}: $1" >&2; }
log_error_terminal() { echo -e "\n${red}Ошибка${reset}: $1" >&2; exit 1; }

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

utils="jq curl grep awk sed ipset"
[ "$name_client" = "mihomo" ] && utils="$utils yq"
for cmd in $utils; do
    command -v "$cmd" >/dev/null 2>&1 || log_error_terminal "Не найдена необходимая утилита: ${yellow}$cmd${reset}"
done

log_clean() { [ "$name_client" = "xray" ] && : > "$log_access" && : > "$log_error"; }

api_cache_init() {
    api_policy_json=$(curl -kfsS "${url_server}/${url_policy}" 2>/dev/null)
    api_port_json=$(curl -kfsS "${url_server}/${url_keenetic_port}" 2>/dev/null)
    api_static_json=$(curl -kfsS "${url_server}/${url_redirect_port}" 2>/dev/null)
}

refresh_port_cache() { api_port_json=$(curl -kfsS "${url_server}/${url_keenetic_port}" 2>/dev/null); }

json_get_ports() { [ -n "$api_port_json" ] && printf '%s' "$api_port_json" | jq -r '.port, (.ssl.port // empty)' 2>/dev/null; }

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

    ip -6 addr show 2>/dev/null | grep -q "inet6 fe80::" || return 0

    wait_for_webui || { log_error_router "Веб-интерфейс недоступен"; return 1; }

    sleep 5

    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1

    for dir in /proc/sys/net/ipv6/conf/*; do
        [ -d "$dir" ] || continue
        iface="${dir##*/}"

        case "$iface" in
            all|ezcfg0|t2s*)
                continue
                ;;
            *)
                [ -f "$dir/disable_ipv6" ] && echo "1" > "$dir/disable_ipv6" 2>/dev/null
                ;;
        esac
    done

    sleep 2

    if [ "$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null)" -eq 1 ]; then
        log_info_router "Отключение IPv6 выполнено"
        return 0
    fi
}

get_ipver_support() {
    ip4_supported=$(ip -4 addr show 2>/dev/null | grep -q "inet " && echo true || echo false)
    ip6_supported=$(ip -6 addr show 2>/dev/null | grep -q "inet6 fe80::" && echo true || echo false)

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
    tmp="${set_name}_tmp"

    # Заполняем tmp; основной набор подменяется только после успешного pipeline
    ipset create "$set_name" hash:net family "$family" -exist
    ipset create "$tmp" hash:net family "$family" -exist
    ipset flush "$tmp"

    if sed -e 's/\r$//' -e 's/#.*//' -e '/^[[:space:]]*$/d' "$file_ip_exclude" |
       grep -Eo "$addr_regex" |
       awk -v s="$tmp" '{print "add "s" "$1}' | ipset restore -exist; then
        ipset swap "$set_name" "$tmp"
    fi
    ipset destroy "$tmp"
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
    [ -n "$raw_donor" ] && port_donor=$(validate_and_clean_ports "$raw_donor" "80,443") || port_donor=""
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
        echo "$val" | grep -Eq '^[0-9a-fA-F]+$' && clean_mark="$clean_mark 0x$val"
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
            strip_json_comments "$file" | jq -e '.dns.servers? != null' >/dev/null 2>&1 && { echo "true"; return; }
        done
    elif [ "$name_client" = "mihomo" ]; then
        [ -f "$mihomo_config" ] && yq -e '.dns.enable == true' "$mihomo_config" >/dev/null 2>&1 && { echo "true"; return; }
    fi

    echo "false"
}
file_dns=$(check_dns_config)

# Кэш списка загруженных модулей; is_module_loaded читает его без форков
_loaded_modules=""
_refresh_modules_cache() { _loaded_modules=" $(lsmod 2>/dev/null | awk '{print $1}' | tr '\n' ' ') "; }

is_module_loaded() {
    case "$_loaded_modules" in
        *" $1 "*) return 0 ;;
        *) return 1 ;;
    esac
}

# Загрузка модулей
load_modules() {
    name="${1%.ko}"
    if ! is_module_loaded "$name"; then
        for dir in "$directory_os_modules" "$directory_user_modules"; do
            [ -f "$dir/$1" ] && insmod "$dir/$1" >/dev/null 2>&1 && return
        done
    fi
}

# Обработка модулей и портов
get_modules() {
    _refresh_modules_cache
    load_modules xt_comment.ko
    load_modules xt_TPROXY.ko
    load_modules xt_socket.ko
    load_modules xt_multiport.ko
    load_modules xt_dscp.ko
    _refresh_modules_cache  # подхватить только что insmod-нутые модули

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
_invalidate_inbounds_cache() { rm -f /tmp/xkeen-inbounds-cache; }

get_xray_transparent_inbounds() {
    cache_file="/tmp/xkeen-inbounds-cache"
    cache_valid=0
    if [ -f "$cache_file" ]; then
        newer=$(find "$directory_xray_config" -maxdepth 1 -name '*.json' -newer "$cache_file" 2>/dev/null | head -n 1)
        [ -z "$newer" ] && cache_valid=1
    fi
    if [ "$cache_valid" = "1" ]; then
        cat "$cache_file"
        return 0
    fi
    cache_tmp="${cache_file}.tmp.$$"
    {
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
    } > "$cache_tmp"
    mv "$cache_tmp" "$cache_file"
    cat "$cache_file"
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
    if [ "$name_client" = "xray" ]; then
        port=$(get_xray_port_by_mode "redirect")
        [ -n "$port" ] && echo "$port" && return 0
    elif [ "$name_client" = "mihomo" ]; then
        port=$(yq eval '.redir-port // ""' "$mihomo_config" 2>/dev/null)
        if [ -z "$port" ]; then
            port=$(yq eval '.listeners[] | select(.type == "redir") | .port // ""' "$mihomo_config" 2>/dev/null)
        fi
        [ -n "$port" ] && echo "$port" && return 0
    else
	return 1
    fi
}

# Получение порта для TProxy
get_port_tproxy() {
    if [ "$name_client" = "xray" ]; then
        port=$(get_xray_port_by_mode "tproxy")
        [ -n "$port" ] && echo "$port" && return 0
    elif [ "$name_client" = "mihomo" ]; then
        port=$(yq eval '.tproxy-port // ""' "$mihomo_config" 2>/dev/null)
        if [ -z "$port" ]; then
            port=$(yq eval '.listeners[] | select(.type == "tproxy") | .port // ""' "$mihomo_config" 2>/dev/null)
        fi
        [ -n "$port" ] && echo "$port" && return 0
    else
	return 1
    fi
}

# Получение сети для Redirect
get_network_redirect() {
    if [ "$name_client" = "xray" ]; then
        network=$(get_xray_network_by_mode "redirect")
        [ -n "$network" ] && echo "$network" && return 0
    elif [ "$name_client" = "mihomo" ]; then
        [ -n "$port_redirect" ] && echo "tcp" && return 0
        echo "" && return 0
    else
	return 1
    fi
}

# Получение сети для TProxy
get_network_tproxy() {
    if [ "$name_client" = "xray" ]; then
        network=$(get_xray_network_by_mode "tproxy")
        [ -n "$network" ] && echo "$network" && return 0
    elif [ "$name_client" = "mihomo" ]; then
        if [ -n "$port_redirect" ] && [ -n "$port_tproxy" ]; then
            echo "udp"
        elif [ -z "$port_redirect" ] && [ -n "$port_tproxy" ]; then
            echo "tcp udp"
        else
            echo ""
        fi
        return 0
    else
	return 1
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
    ipv4_eth=$(ip -o route get 195.208.4.1 2>/dev/null | sed -n 's/.*src \([^ ]*\).*/\1/p' || \
               ip -o route get 77.88.8.8 2>/dev/null | sed -n 's/.*src \([^ ]*\).*/\1/p')
    [ -n "$ipv4_eth" ] && ipv4_eth="${ipv4_eth}/32"
    echo "${ipv4_eth} ${ipv4_exclude}" | tr ' ' '\n' | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/^ //; s/ $//'
}

# Получение исключений IPv6
get_exclude_ip6() {
    [ "$ip6tables_supported" != "true" ] && return

    # Получаем провайдерский IPv6
    ipv6_eth=$(ip -o -6 route get 2a0c:a9c7:8::1 2>/dev/null | sed -n 's/.*src \([^ ]*\).*/\1/p' || \
               ip -o -6 route get 2a02:6b8::feed:0ff 2>/dev/null | sed -n 's/.*src \([^ ]*\).*/\1/p')
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
            log_error_router "Ошибка конфигурации: Имя политики в xkeen.json совпадает с зарезервированным"
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
    [ -f "$xkeen_config" ] && [ -n "$api_policy_json" ] || return

    api_exclude_ports=$(get_api_exclude_ports)

    # Получаем сопоставленные политики одним вызовом jq
    matched_policies=$(printf '%s' "$api_policy_json" | jq -r --argjson user_cfg "$(cat "$xkeen_config")" '
        ($user_cfg.xkeen.policy // []) as $up |
        .[] as $api |
        $up[] | 
        select(
            (.name | ascii_downcase) == 
            ($api.description | ascii_downcase)
        ) |
        "\(.name)|\($api.mark)|\(.port // "")"
    ' 2>/dev/null)

    [ -z "$matched_policies" ] && return

    # Обрабатываем каждую политику в одном цикле
    echo "$matched_policies" | while IFS='|' read -r pname mark pports; do
        if [ -z "$pports" ]; then
            # Порты не указаны -> режим "all" (все порты)
            if [ -n "$api_exclude_ports" ]; then
                echo "${pname}|${mark}|exclude|${api_exclude_ports}"
            else
                echo "${pname}|${mark}|all|"
            fi
        else

            case "$pports" in
                !*) mode="exclude"; ports="${pports#!}"
                    [ -n "$api_exclude_ports" ] && ports="${ports:+$ports,}$api_exclude_ports" ;;
                *) mode="include"; ports="$pports"
                    if [ "$file_dns" = "true" ] && [ "$proxy_dns" = "on" ]; then
                        case ",$ports," in
                            *,53,*) ;;
                            *) ports="53,$ports" ;;
                        esac
                    fi
                    ;;
            esac

            clean_ports=$(validate_and_clean_ports "$ports")
            [ -n "$clean_ports" ] && echo "${pname}|${mark}|${mode}|${clean_ports}"
        fi
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

    # Pre-evaluate dynamic variables
    val_exclude_ip6="$(get_exclude_ip6)"
    val_exclude_ip4="$(get_exclude_ip4)"

    cat > "$file_netfilter_hook" <<'EOL'
#!/bin/sh
# XKeen: Auto-generated file. DO NOT EDIT!
[ -f /tmp/xkeen_ready ] || exit 0
EOL

    # Securely inject variables into the script
    inject_var() {
        local name="$1"
        local val="$2"
        local safe_val
        safe_val="${val//\'/\'\\\'\'}"
        printf "%s='%s'\n" "$name" "$safe_val" >> "$file_netfilter_hook"
    }

    inject_var name_client "$name_client"
    inject_var name_profile "$name_profile"
    inject_var mode_proxy "$mode_proxy"
    inject_var network_redirect "$network_redirect"
    inject_var network_tproxy "$network_tproxy"
    inject_var networks "$networks"
    inject_var name_chain "$name_chain"
    inject_var port_redirect "$port_redirect"
    inject_var port_tproxy "$port_tproxy"
    inject_var port_donor "$port_donor"
    inject_var port_exclude "$port_exclude"
    inject_var policy_mark "$policy_mark"
    inject_var comment_tag "$comment_tag"
    inject_var comment "$comment"
    inject_var custom_mark "$custom_mark"
    inject_var dscp_exclude "$dscp_exclude"
    inject_var dscp_proxy "$dscp_proxy"
    inject_var user_policies "$user_policies"
    inject_var table_redirect "$table_redirect"
    inject_var table_tproxy "$table_tproxy"
    inject_var table_mark "$table_mark"
    inject_var table_id "$table_id"
    inject_var gid_xkeen "$gid_xkeen"
    inject_var group_xkeen "$group_xkeen"
    inject_var file_dns "$file_dns"
    inject_var proxy_dns "$proxy_dns"
    inject_var proxy_router "$proxy_router"
    inject_var directory_os_modules "$directory_os_modules"
    inject_var directory_user_modules "$directory_user_modules"
    inject_var directory_configs_app "$directory_configs_app"
    inject_var directory_xray_config "$directory_xray_config"
    inject_var directory_xray_asset "$directory_xray_asset"
    inject_var iptables_supported "$iptables_supported"
    inject_var ip6tables_supported "$ip6tables_supported"
    inject_var arm64_fd "$arm64_fd"
    inject_var other_fd "$other_fd"
    inject_var aghfix "$aghfix"
    
    inject_var ipv6_proxy "$ipv6_proxy"
    inject_var ipv4_proxy "$ipv4_proxy"
    inject_var val_exclude_ip6 "$val_exclude_ip6"
    inject_var val_exclude_ip4 "$val_exclude_ip4"

    cat >> "$file_netfilter_hook" <<'EOL'

# Перезапуск скрипта
restart_script() {
    exec /bin/sh "$0" "$@"
}

# Группа xkeen для GID-based маршрутизации трафика прокси-ядра. Полная версия
# в /opt/etc/init.d/S05xkeen — здесь дубликат для self-contained netfilter-hook
# (вызывается ndm-ом раньше чем S05xkeen).
ensure_group_xkeen() {
    [ -f /etc/group ] || return 1
    existing_gid=$(awk -F: -v g="$group_xkeen" '$1==g{print $3}' /etc/group 2>/dev/null)
    if [ -n "$existing_gid" ]; then
        gid_xkeen="$existing_gid"
        return 0
    fi
    printf '%s:x:%s:\n' "$group_xkeen" "$gid_xkeen" >> /etc/group
}

if pidof "$name_client" >/dev/null; then

    # Аккумулируем правила в строки, применяем атомарно одним
    # iptables-restore --noflush на (family, table) в _xkeen_apply.
    # Сохраняем семантику старого ipt() для всех существующих helper'ов.
    _xkeen_v4_nat_rules=""
    _xkeen_v4_mangle_rules=""
    _xkeen_v6_nat_rules=""
    _xkeen_v6_mangle_rules=""

    ipt() {
        [ "$family" = "iptables" ] && [ "$iptables_supported" != "true" ] && return 0
        [ "$family" = "ip6tables" ] && [ "$ip6tables_supported" != "true" ] && return 0

        case "$1" in
            -A|-I|-D)
                _line=$*
                case "${family}_${table}" in
                    iptables_nat)     _xkeen_v4_nat_rules="${_xkeen_v4_nat_rules}${_line}
" ;;
                    iptables_mangle)  _xkeen_v4_mangle_rules="${_xkeen_v4_mangle_rules}${_line}
" ;;
                    ip6tables_nat)    _xkeen_v6_nat_rules="${_xkeen_v6_nat_rules}${_line}
" ;;
                    ip6tables_mangle) _xkeen_v6_mangle_rules="${_xkeen_v6_mangle_rules}${_line}
" ;;
                esac
                return 0
                ;;
            *)
                # Прочие операции (-F, -X) - в реальный iptables.
                if [ "$family" = "iptables" ]; then
                    iptables -w -t "$table" "$@"
                else
                    ip6tables -w -t "$table" "$@"
                fi
                return $?
                ;;
        esac
    }

    # Применяет аккумулированные правила одной таблицы атомарно через
    # iptables-restore --noflush. Custom chain $name_chain flush'ится
    # объявлением ":$name_chain -" перед добавлением новых правил.
    _xkeen_apply_table() {
        _family="$1"
        _table="$2"
        _rules_var="$3"

        eval "_rules=\${$_rules_var}"
        [ -z "$_rules" ] && return 0

        # Удаляем устаревшие xkeen-tagged правила из built-in/system chain'ов
        # (PREROUTING, OUTPUT, _NDM_HOTSPOT_DNSREDIR), правила из самой $name_chain
        # игнорируются - там ":chain -" в blob их сам flush'ит.
        save_cmd=""
        [ "$_family" = "iptables" ] && [ "$iptables_supported" = "true" ] && save_cmd="iptables-save"
        [ "$_family" = "ip6tables" ] && [ "$ip6tables_supported" = "true" ] && save_cmd="ip6tables-save"
        [ -z "$save_cmd" ] && { _deletes=""; return; }

        _deletes=$($save_cmd -t "$_table" 2>/dev/null | awk \
            -v tag="$comment_tag" \
            -v c1="$name_chain" \
            -v c2="${name_chain}_out" '
            index($0, tag) &&
            $1 == "-A" &&
            $2 != c1 &&
            $2 != c2 {
                sub(/^-A /, "-D ")
                print
            }
        ')

        {
            printf '*%s\n' "$_table"
            printf ':%s -\n' "$name_chain"
            [ "$proxy_router" = "on" ] && printf ':%s_out -\n' "$name_chain"
            [ -n "$_deletes" ] && printf '%s\n' "$_deletes"
            printf '%s' "$_rules"
            printf 'COMMIT\n'
        } | if [ "$_family" = "iptables" ]; then
            iptables-restore --noflush
        else
            ip6tables-restore --noflush
        fi
    }

    _xkeen_apply() {
        [ "$iptables_supported" = "true" ] && _xkeen_apply_table iptables nat _xkeen_v4_nat_rules || true
        [ "$iptables_supported" = "true" ] && _xkeen_apply_table iptables mangle _xkeen_v4_mangle_rules || true
        [ "$ip6tables_supported" = "true" ] && _xkeen_apply_table ip6tables nat _xkeen_v6_nat_rules || true
        [ "$ip6tables_supported" = "true" ] && _xkeen_apply_table ip6tables mangle _xkeen_v6_mangle_rules || true
    }

    # Добавление правил-исключений
    add_exclude_rules() {
        chain="$1"
        for exclude in $exclude_list; do
            if [ "$file_dns" = "true" ] && [ "$proxy_dns" = "on" ] && [ "$chain" != "${name_chain}_out" ]; then
                case "$exclude" in
                    10.0.0.0/8|172.16.0.0/12|192.168.0.0/16|fd00::/8|fe80::/10)
                    if [ "$table" = "mangle" ] && [ "$mode_proxy" = "Hybrid" ]; then
                        ipt -A "$chain" -d "$exclude" -p tcp --dport 53 $comment -j RETURN >/dev/null 2>&1
                        ipt -A "$chain" -d "$exclude" -p udp ! --dport 53 $comment -j RETURN >/dev/null 2>&1
                    elif [ "$table" = "nat" ] && [ "$mode_proxy" = "Hybrid" ]; then
                        ipt -A "$chain" -d "$exclude" -p tcp ! --dport 53 $comment -j RETURN >/dev/null 2>&1
                        ipt -A "$chain" -d "$exclude" -p udp --dport 53 $comment -j RETURN >/dev/null 2>&1
                    elif [ "$table" = "mangle" ] && [ "$mode_proxy" = "TProxy" ]; then
                        ipt -A "$chain" -d "$exclude" -p tcp ! --dport 53 $comment -j RETURN >/dev/null 2>&1
                        ipt -A "$chain" -d "$exclude" -p udp ! --dport 53 $comment -j RETURN >/dev/null 2>&1
                    fi
                    ;;
                esac
            else
                ipt -A "$chain" -d "$exclude" $comment -j RETURN >/dev/null 2>&1
            fi
        done
    }

    add_ipset_exclude() {
        base_set="$1"
        set_type="${2:-hash:net}"

        if [ "$family" = "ip6tables" ]; then
            set_name="${base_set}6"
            ipset_family="inet6"
        else
            set_name="$base_set"
            ipset_family="inet"
        fi

        ipset create "$set_name" "$set_type" family "$ipset_family" -exist || return

        ipt -I "$chain" 1 -m set --match-set "$set_name" dst $comment -j RETURN >/dev/null 2>&1
    }

    # Добавление правил iptables
    add_ipt_rule() {
        family="$1"
        table="$2"
        chain="$3"
        shift 3
        [ "$family" = "iptables" ] && [ "$iptables_supported" = "false" ] && return
        [ "$family" = "ip6tables" ] && [ "$ip6tables_supported" = "false" ] && return

        # Custom chain создаётся/flush'ится одной строкой ":$name_chain -" в blob,
        # поэтому ни -nL guard, ни -N не нужны - всегда заполняем body.
        add_exclude_rules "$chain"

        if [ "$table" = "$table_tproxy" ]; then
            if [ "$mode_proxy" = "Hybrid" ]; then
                set -- -p udp -m conntrack --ctstate ESTABLISHED,RELATED $comment -j CONNMARK --restore-mark
            else
                set -- -m conntrack --ctstate ESTABLISHED,RELATED $comment -j CONNMARK --restore-mark
            fi
            ipt -I "$chain" 1 "$@" >/dev/null 2>&1
        fi

        case "$mode_proxy" in
            Hybrid)
                if [ "$table" = "$table_redirect" ]; then
                    ipt -I "$chain" 1 -m conntrack --ctstate DNAT $comment -j RETURN >/dev/null 2>&1
                    add_ipset_exclude ext_exclude hash:ip
                    add_ipset_exclude geo_exclude hash:net
                    add_ipset_exclude user_exclude hash:net
                    ipt -A "$chain" -p tcp $comment -j REDIRECT --to-port "$port_redirect" >/dev/null 2>&1
                else
                    ipt -I "$chain" 1 -m conntrack --ctstate DNAT $comment -j RETURN >/dev/null 2>&1
                    add_ipset_exclude ext_exclude hash:ip
                    add_ipset_exclude geo_exclude hash:net
                    add_ipset_exclude user_exclude hash:net
                    ipt -A "$chain" -p udp -m socket --transparent $comment -j MARK --set-mark "$table_mark" >/dev/null 2>&1
                    ipt -A "$chain" -p udp -m mark ! --mark 0 $comment -j CONNMARK --save-mark >/dev/null 2>&1
                    ipt -A "$chain" -p udp $comment -j TPROXY --on-ip "$proxy_ip" --on-port "$port_tproxy" --tproxy-mark "$table_mark" >/dev/null 2>&1
                fi
                ;;
            TProxy)
                ipt -I "$chain" 1 -m conntrack --ctstate DNAT $comment -j RETURN >/dev/null 2>&1
                for net in $network_tproxy; do
                    add_ipset_exclude ext_exclude hash:ip
                    add_ipset_exclude geo_exclude hash:net
                    add_ipset_exclude user_exclude hash:net
                    ipt -A "$chain" -p "$net" -m socket --transparent $comment -j MARK --set-mark "$table_mark" >/dev/null 2>&1
                    ipt -A "$chain" -p "$net" -m mark ! --mark 0 $comment -j CONNMARK --save-mark >/dev/null 2>&1
                    ipt -A "$chain" -p "$net" $comment -j TPROXY --on-ip "$proxy_ip" --on-port "$port_tproxy" --tproxy-mark "$table_mark" >/dev/null 2>&1
                done
                ;;
            Redirect)
                ipt -I "$chain" 1 -m conntrack --ctstate DNAT $comment -j RETURN >/dev/null 2>&1
                add_ipset_exclude ext_exclude hash:ip
                add_ipset_exclude geo_exclude hash:net
                add_ipset_exclude user_exclude hash:net
                for net in $network_redirect; do
                    ipt -A "$chain" -p "$net" $comment -j REDIRECT --to-port "$port_redirect" >/dev/null 2>&1
                done
                ;;
            *) exit 0 ;;
        esac

        if [ -n "$dscp_exclude" ]; then
            for dscp in $dscp_exclude; do
                ipt -I "$chain" -m dscp --dscp "$dscp" $comment -j RETURN >/dev/null 2>&1
            done
        fi

        # Ответы upstream-серверов на исходящие xray-запросы возвращаются
        # на роутер с connmark=policy_mark (NDM CONNMARK --restore-mark).
        # PREROUTING-jump в xkeen chain по connmark может зациклить их
        # через TPROXY/REDIRECT, поэтому пакеты адресованные самому
        # роутеру (любой его IP) — пропускаем.
        ipt -I "$chain" 1 -m addrtype --dst-type LOCAL $comment -j RETURN >/dev/null 2>&1
    }

    # Настройка таблицы маршрутов
    configure_route() {
        ip_version="$1"

        # Определяем таблицу маршрутизации
        if [ -n "$policy_mark" ]; then
            policy_table=$(ip rule show | awk -v policy="$policy_mark" '$0 ~ policy && /lookup/ && !/blackhole/ {print $(NF); exit}')
        fi
        source_table="${policy_table:-main}"

        # Проверяем есть ли default маршрут
        check_default() {
            if [ "$ip_version" = "6" ] && ! ip -6 route show default 2>/dev/null | grep -q .; then
                return 0
            fi
            if [ "$source_table" = "main" ]; then
                ip -"$ip_version" route show default 2>/dev/null | grep -q '^default'
            else
                ip -"$ip_version" route show table all 2>/dev/null | grep -E "^[[:space:]]*default .* table $policy_table([[:space:]]|$)" | grep -vq 'unreachable' >/dev/null
            fi
        }

        attempts=0
        max_attempts=4
        until check_default; do
            attempts=$((attempts + 1))
            if [ "$attempts" -ge "$max_attempts" ]; then
                [ "$ip_version" = "4" ] && touch "/tmp/noinet"
                return 1
            fi
            sleep 1
        done
        [ "$ip_version" = "4" ] && rm -f "/tmp/noinet"

        ip -"$ip_version" rule del fwmark "$table_mark" lookup "$table_id" >/dev/null 2>&1 || true
        ip -"$ip_version" route flush table "$table_id" >/dev/null 2>&1 || true
        ip -"$ip_version" route add local default dev lo table "$table_id" >/dev/null 2>&1 || true
        ip -"$ip_version" rule add fwmark "$table_mark" lookup "$table_id" >/dev/null 2>&1 || true

        # Копируем маршруты
        ip -"$ip_version" route show table "$source_table" 2>/dev/null | while read -r route_line; do
            case "$route_line" in
                default*|unreachable*|blackhole*) continue ;;
                *) ip -"$ip_version" route add table "$table_id" $route_line >/dev/null 2>&1 || true ;;
            esac
        done
        return 0
    }

    # Создание множественных правил multiport
    add_multiport_rules() {
        family="$1"
        table="$2"
        net="$3"
        mark="$4"
        ports="$5"
        target="$6"

        [ -z "$ports" ] && return

        num_ports=$(echo "$ports" | tr ',' '\n' | wc -l)
        i=1
        while [ "$i" -le "$num_ports" ]; do
            end=$((i + 6))
            chunk=$(echo "$ports" | tr ',' '\n' | sed -n "${i},${end}p" | tr '\n' ',' | sed 's/,$//')
            [ -z "$chunk" ] && break
            if [ -n "$mark" ]; then
                set -- -m connmark --mark "$mark" -m conntrack ! --ctstate INVALID -p "$net" -m multiport --dports "$chunk" $comment -j "$target"
            else
                set -- -m conntrack ! --ctstate INVALID -p "$net" -m multiport --dports "$chunk" $comment -j "$target"
            fi
            ipt -A PREROUTING "$@" >/dev/null 2>&1
            i=$((i + 7))
        done
    }

    # Добавление цепочек PREROUTING
    add_prerouting() {
        family="$1"
        table="$2"

        for net in $networks; do
            if [ "$mode_proxy" = "Hybrid" ]; then
                [ "$table" = "nat"    ] && [ "$net" != "tcp" ] && continue
                [ "$table" = "mangle" ] && [ "$net" != "udp" ] && continue
            fi

            if [ "$mode_proxy" = "TProxy" ]; then
                proto_match=""
            else
                proto_match="-p $net"
            fi

            for dscp in $dscp_proxy; do
                set -- -m conntrack ! --ctstate INVALID $proto_match -m dscp --dscp "$dscp" $comment -j "$name_chain"
                ipt -A PREROUTING "$@" >/dev/null 2>&1
            done

            if [ "$proxy_router" = "on" ]; then
                set -- -i lo -m mark --mark "$table_mark" $proto_match $comment -j "$name_chain"
                ipt -A PREROUTING "$@" >/dev/null 2>&1
            fi

            # Пользовательские политики из xkeen.json
            # Heredoc вместо echo|while - while должен исполниться в parent shell,
            # чтобы аккумуляторы _xkeen_*_rules в ipt() модифицировались в нужном scope.
            while IFS='|' read -r pname pmark pmode pports; do
                [ -z "$pmark" ] && continue

                pmark=$(echo "$pmark" | tr -d ' \r\n')
                pmode=$(echo "$pmode" | tr -d ' \r\n')
                pports=$(echo "$pports" | tr -d ' \r\n')

                if [ "$pmode" = "all" ]; then
                    set -- -m connmark --mark 0x"$pmark" -m conntrack ! --ctstate INVALID $comment -j "$name_chain"
                    ipt -A PREROUTING "$@" >/dev/null 2>&1
                elif [ "$pmode" = "include" ]; then
                    add_multiport_rules "$family" "$table" "$net" "0x$pmark" "$pports" "$name_chain"
                elif [ "$pmode" = "exclude" ]; then
                    add_multiport_rules "$family" "$table" "$net" "0x$pmark" "$pports" "RETURN"
                    set -- -m connmark --mark 0x"$pmark" -m conntrack ! --ctstate INVALID -p "$net" $comment -j "$name_chain"
                    ipt -A PREROUTING "$@" >/dev/null 2>&1
                fi
            done <<USER_POLICIES_EOF
$user_policies
USER_POLICIES_EOF

            # Политика xkeen (стандартная)
            if [ -n "$policy_mark" ]; then
                # заданы порты проксирования
                if [ -n "$port_donor" ]; then
                    add_multiport_rules "$family" "$table" "$net" "$policy_mark" "$port_donor" "$name_chain"
                # заданы порты исключения
                elif [ -n "$port_exclude" ]; then
                    add_multiport_rules "$family" "$table" "$net" "$policy_mark" "$port_exclude" "RETURN"
                    set -- -m connmark --mark "$policy_mark" -m conntrack ! --ctstate INVALID -p "$net" $comment -j "$name_chain"
                    ipt -A PREROUTING "$@" >/dev/null 2>&1
                else
                    # Политика xkeen, когда порты не указаны (проксирование на всех портах)
                    set -- -m connmark --mark "$policy_mark" -m conntrack ! --ctstate INVALID $comment -j "$name_chain"
                    ipt -A PREROUTING "$@" >/dev/null 2>&1
                fi
            # НЕТ политики xkeen
            else
                # заданы порты проксирования
                if [ -n "$port_donor" ]; then
                    add_multiport_rules "$family" "$table" "$net" "" "$port_donor" "$name_chain"
                # заданы порты исключения
                elif [ -n "$port_exclude" ]; then
                    add_multiport_rules "$family" "$table" "$net" "" "$port_exclude" "RETURN"
                    set -- -m conntrack ! --ctstate INVALID -p "$net" $comment -j "$name_chain"
                    ipt -A PREROUTING "$@" >/dev/null 2>&1
                # Если нет ни xkeen, ни пользовательских политик -> перехватываем всё
                else
                    set -- -m conntrack ! --ctstate INVALID $comment -j "$name_chain"
                    ipt -A PREROUTING "$@" >/dev/null 2>&1
                fi
            fi
        done
    }

    # Добавление цепочек для проксирования трафика Entware
    add_output() {
        family="$1"
        table="$2"

        [ "$proxy_router" != "on" ] && return

        out_chain="${name_chain}_out"

        # ":${name_chain}_out -" в blob создаст/flush'ит chain атомарно,
        # body заполняется всегда.
        orig_chain="$chain"
        chain="$out_chain"

        ipt -A "$out_chain" -o lo $comment -j RETURN >/dev/null 2>&1
        ipt -A "$out_chain" -m mark --mark 255 $comment -j RETURN >/dev/null 2>&1

        add_exclude_rules "$out_chain"

        add_ipset_exclude ext_exclude hash:ip
        add_ipset_exclude geo_exclude hash:net
        add_ipset_exclude user_exclude hash:net

        chain="$orig_chain"

        for net in $networks; do
            if [ "$mode_proxy" = "Hybrid" ]; then
                [ "$table" = "nat"    ] && [ "$net" != "tcp" ] && continue
                [ "$table" = "mangle" ] && [ "$net" != "udp" ] && continue
            fi

            if [ "$mode_proxy" = "TProxy" ]; then
                proto_match=""
            else
                proto_match="-p $net"
            fi

            set -- -m conntrack ! --ctstate INVALID $proto_match $comment -j "$out_chain"
            ipt -A OUTPUT "$@" >/dev/null 2>&1

            if [ "$table" = "$table_redirect" ]; then
                set -- -p "$net" $comment -j REDIRECT --to-port "$port_redirect"
                ipt -A "$out_chain" "$@" >/dev/null 2>&1
            elif [ "$table" = "$table_tproxy" ]; then
                set -- -p "$net" $comment -j MARK --set-mark "$table_mark"
                ipt -A "$out_chain" "$@" >/dev/null 2>&1
            fi
        done
    }

    # Маркирует исходящие сокеты xray/mihomo меткой Keenetic policy_mark.
    # NDM для каждой пользовательской политики создаёт правило
    # "ip rule fwmark <pmark> lookup <ptable>", где ptable содержит default
    # через выбранный в policy WAN (основной или резервный). Match по GID —
    # точечный, системный трафик роутера (под другими GID) метку не получает
    # и продолжает идти через main как раньше.
    # Без этой функции исходящие сокеты xray всегда идут через main table
    # и игнорируют резерв.
    add_output_policy_mark() {
        family="$1"
        table="$2"

        [ "$table" = "$table_tproxy" ] || return 0
        [ -z "$policy_mark" ] && return 0
        [ -z "$gid_xkeen" ] && return 0

        set -- -m owner --gid-owner "$gid_xkeen" -m mark --mark 0x0 $comment -j MARK --set-mark "$policy_mark"
        ipt -A OUTPUT "$@" >/dev/null 2>&1
        set -- -m owner --gid-owner "$gid_xkeen" -m conntrack ! --ctstate INVALID $comment -j CONNMARK --save-mark
        ipt -A OUTPUT "$@" >/dev/null 2>&1
    }

    dns_redir() {
        family="$1"
        table="nat"

        [ "$aghfix" != "on" ] && return
        [ "$file_dns" = "true" ] && [ "$proxy_dns" = "on" ] && return

        all_marks=""
        [ -n "$policy_mark" ] && all_marks="$policy_mark"

        [ -n "$custom_mark" ] && all_marks="$custom_mark $all_marks"

        if [ -n "$user_policies" ]; then
            user_marks=$(echo "$user_policies" | awk -F'|' '{if ($2 != "") print "0x"$2}')
            all_marks="$all_marks $user_marks"
        fi

        for mark in $all_marks; do
            mark=$(echo "$mark" | tr -d ' \r\n')
            [ -z "$mark" ] && continue

            for proto in udp tcp; do
                set -- -p "$proto" -m mark --mark "$mark" -m pkttype --pkt-type unicast -m "$proto" --dport 53 $comment -j REDIRECT --to-ports 53
                ipt -I _NDM_HOTSPOT_DNSREDIR "$@" >/dev/null 2>&1
            done
        done
    }

    if [ -n "$port_donor" ] || [ -n "$port_exclude" ]; then
        [ "$file_dns" = "true" ] && [ "$proxy_dns" = "on" ] && [ -n "$port_donor" ] && port_donor="53,$port_donor"
    fi

    # Группа xkeen создаётся в proxy_start через ensure_group_xkeen, но
    # netfilter-hook может вызываться раньше (после reboot до S05xkeen) —
    # гарантируем готовность group здесь тоже.
    ensure_group_xkeen || true

    for family in iptables ip6tables; do

        [ "$family" = "ip6tables" ] && [ "$ip6tables_supported" != "true" ] && continue
        [ "$family" = "iptables" ] && [ "$iptables_supported" != "true" ] && continue

        if [ "$family" = "ip6tables" ]; then
            exclude_list="$val_exclude_ip6"
            proxy_ip="$ipv6_proxy"
            configure_route 6
        else
            exclude_list="$val_exclude_ip4"
            proxy_ip="$ipv4_proxy"
            configure_route 4
        fi
        if [ -n "$port_redirect" ] && [ -n "$port_tproxy" ]; then
            for table in "$table_tproxy" "$table_redirect"; do
                add_ipt_rule "$family" "$table" "$name_chain"
                add_prerouting "$family" "$table"
                add_output "$family" "$table"
                add_output_policy_mark "$family" "$table"
            done
        elif [ -z "$port_redirect" ] && [ -n "$port_tproxy" ]; then
            table="$table_tproxy"
            add_ipt_rule "$family" "$table" "$name_chain"
            add_prerouting "$family" "$table"
            add_output "$family" "$table"
            add_output_policy_mark "$family" "$table"
        elif [ -n "$port_redirect" ] && [ -z "$port_tproxy" ]; then
            table="$table_redirect"
            add_ipt_rule "$family" "$table" "$name_chain"
            add_prerouting "$family" "$table"
            add_output "$family" "$table"
            add_output_policy_mark "$family" "$table"
        fi

        dns_redir "$family"
    done

    # Атомарно применяем все аккумулированные правила одним
    # iptables-restore --noflush per (family, table).
    _xkeen_apply
else
    [ -f "/tmp/xkeen_starting.lock" ] && exit 0
    touch "/tmp/xkeen_starting.lock"
    . "/opt/sbin/.xkeen/01_info/03_info_cpu.sh"
    status_file="/opt/lib/opkg/status"
    info_cpu

    fd_limit="$other_fd"
    [ "$architecture" = "arm64-v8a" ] && fd_limit="$arm64_fd"
    ulimit -SHn "$fd_limit"

    ensure_group_xkeen || true

    # Запуск с GID=$gid_xkeen через start-stop-daemon -c — исходящие сокеты
    # xray/mihomo попадут под `-m owner --gid-owner` в OUTPUT mangle и уйдут
    # через WAN политики Keenetic. Если start-stop-daemon -c недоступен
    # (старый busybox) — fallback на обычный `&` под root:root (трафик через
    # main, без policy-routing).
    case "$name_client" in
        xray)
            export XRAY_LOCATION_CONFDIR="$directory_xray_config"
            export XRAY_LOCATION_ASSET="$directory_xray_asset"
            if ! start-stop-daemon -S -b -q -c "0:${gid_xkeen}" -x "$name_client" -- run 2>/dev/null; then
                "$name_client" run >/dev/null 2>&1 &
            fi
        ;;
        mihomo)
            export CLASH_HOME_DIR="$directory_configs_app"
            if ! start-stop-daemon -S -b -q -c "0:${gid_xkeen}" -x "$name_client" 2>/dev/null; then
                "$name_client" >/dev/null 2>&1 &
            fi
        ;;
    esac
    _probe=0
    while [ "$_probe" -lt 60 ]; do
        pidof "$name_client" >/dev/null 2>&1 && break
        _probe=$((_probe + 1))
        usleep 100000
    done
    unset _probe
    rm -f "/tmp/xkeen_starting.lock"
    if pidof "$name_client" >/dev/null; then
        restart_script "$@"
    else
        exit 1
    fi
fi
EOL
    sed -i '1,2!{/^[[:space:]]*#/d; /^[[:space:]]*$/d}' "$file_netfilter_hook"
    chmod 700 "$file_netfilter_hook"
    sh "$file_netfilter_hook"
}

# Удаление правил iptables
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
    tmp="${set}_tmp"

    # Заполняем tmp; основной набор подменяется только после успешного restore
    ipset create "$set" hash:net family "$family" -exist
    ipset create "$tmp" hash:net family "$family" -exist
    ipset flush "$tmp"

    if [ -f "$file" ] && sed -e 's/\r$//' -e 's/#.*//' -e '/^[[:space:]]*$/d' "$file" | awk '{print "add '"$tmp"' "$1}' | ipset restore -exist; then
        ipset swap "$set" "$tmp"
    fi
    ipset destroy "$tmp"
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

# Гарантирует наличие группы xkeen в /etc/group (idempotent).
# busybox addgroup может отсутствовать или требовать /etc/shadow — пишем
# напрямую, это переносимо на любом POSIX.
ensure_group_xkeen() {
    [ -f /etc/group ] || return 1
    existing_gid=$(awk -F: -v g="$group_xkeen" '$1==g{print $3}' /etc/group 2>/dev/null)
    if [ -n "$existing_gid" ]; then
        gid_xkeen="$existing_gid"
        return 0
    fi
    printf '%s:x:%s:\n' "$group_xkeen" "$gid_xkeen" >> /etc/group
}

missing_files_template='
  '"${light_blue}"'Отсутствуют исполняемые файлы:'"${reset}"'
  '"${yellow}"'%b'"${reset}"'

  '"${green}"'Возможные причины:'"${reset}"'
  • XKeen установлен во внутреннюю память и на ней недостаточно места
  • У файла отсутствуют права на выполнение

  '"${green}"'Рекомендуемые действия:'"${reset}"'
  • Переустановите XKeen на внешний накопитель
  • Скопируйте недостающий файл вручную и сделайте исполняемым
'

check_binary() {
    file="$1"
    path="$install_dir/$file"

    if [ ! -f "$path" ] || [ ! -x "$path" ]; then
        return 1
    fi

    check_cmd="version"
    [ "$file" = "xray" ] && check_cmd="version"
    [ "$file" = "yq" ] && check_cmd="--version"
    [ "$file" = "mihomo" ] && check_cmd="-v"

    if ! "$file" $check_cmd >/dev/null 2>&1; then
        log_error_router "Бинарный файл $file аварийно остановлен"
        log_error_terminal "
  Бинарный файл ${yellow}$file${reset} аварийно остановлен
  ${red}Файл повреждён или несовместим с процессором${reset} вашего роутера
  Установите другую версию ${yellow}$file${reset}
"
    fi

    return 0
}

info_health_binary() {
    missing_files=""

    add_to_missing() {
        file_name="$1"
        prefix="  - " 
        
        if [ -z "$missing_files" ]; then
            missing_files="${prefix}${yellow}${file_name}${reset}"
        else
            missing_files="${missing_files}\n  ${prefix}${yellow}${file_name}${reset}"
        fi
    }

    case "$name_client" in
        xray)
            if ! check_binary xray; then add_to_missing "xray"; fi
            ;;
       mihomo)
            for file in mihomo yq; do
                if ! check_binary "$file"; then add_to_missing "$file"; fi
            done
            ;;
        esac

    if [ -n "$missing_files" ]; then
        log_error_terminal "$(printf "$missing_files_template" "$missing_files")"
    fi
}

# Запуск прокси-клиента
proxy_start() {
    start_manual="$1"
    if [ "$start_manual" = "on" ] || [ "$start_auto" = "on" ]; then
        _invalidate_inbounds_cache
        apply_ipv6_state
        get_ipver_support
        info_health_binary
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
            # Marker до configure_firewall: тот завершается `sh proxy.sh`,
            # gate в хуке читает /tmp/xkeen_ready.
            touch "/tmp/xkeen_ready"
            [ "$mode_proxy" != "Other" ] && configure_firewall
            if [ "$start_manual" = "on" ]; then
                log_error_terminal "Не удалось запустить ${yellow}$name_client${reset}, так как он уже запущен"
            else
                log_info_router "Прокси-клиент успешно запущен в режиме $mode_proxy"
                rm -f "/tmp/xkeen_coldstart.lock"
            fi
        else
            log_info_router "Инициирован запуск прокси-клиента"
            attempt=1
            . "/opt/sbin/.xkeen/01_info/03_info_cpu.sh"
            status_file="/opt/lib/opkg/status"
            info_cpu
            while [ "$attempt" -le "$start_attempts" ]; do
                ensure_group_xkeen || true
                case "$name_client" in
                    xray)
                        export XRAY_LOCATION_CONFDIR="$directory_xray_config"
                        export XRAY_LOCATION_ASSET="$directory_xray_asset"
                        find "$directory_xray_config" -maxdepth 1 -name '._*.json' -type f -delete
                        apply_fd_limit
                        if [ -n "$fd_out" ]; then
                            if ! start-stop-daemon -S -b -q -c "0:${gid_xkeen}" -x "$name_client" -- run 2>/dev/null; then
                                nohup "$name_client" run >/dev/null 2>&1 &
                            fi
                            unset fd_out
                        else
                            if ! start-stop-daemon -S -b -q -c "0:${gid_xkeen}" -x "$name_client" -- run 2>/dev/null; then
                                "$name_client" run &
                            fi
                        fi
                    ;;
                    mihomo)
                        export CLASH_HOME_DIR="$directory_configs_app"
                        apply_fd_limit
                        if [ -n "$fd_out" ]; then
                            if ! start-stop-daemon -S -b -q -c "0:${gid_xkeen}" -x "$name_client" 2>/dev/null; then
                                nohup "$name_client" >/dev/null 2>&1 &
                            fi
                            unset fd_out
                        else
                            if ! start-stop-daemon -S -b -q -c "0:${gid_xkeen}" -x "$name_client" 2>/dev/null; then
                                "$name_client" &
                            fi
                        fi
                        ;;
                    *) log_error_terminal "Неизвестный прокси-клиент: ${yellow}$name_client${reset}" ;;
                esac
                _probe_attempt=0
                while [ "$_probe_attempt" -lt 60 ]; do
                    proxy_status && break
                    _probe_attempt=$((_probe_attempt + 1))
                    usleep 50000
                done
                unset _probe_attempt
                if proxy_status; then
                    # См. alive-branch: marker до configure_firewall.
                    touch "/tmp/xkeen_ready"
                    [ "$mode_proxy" != "Other" ] && configure_firewall
                    _pids=""
                    [ "$iptables_supported" = "true" ] && [ -f "$ru_exclude_ipv4" ] && { load_ipset geo_exclude "$ru_exclude_ipv4" inet & _pids="$_pids $!"; }
                    [ "$ip6tables_supported" = "true" ] && [ -f "$ru_exclude_ipv6" ] && { load_ipset geo_exclude6 "$ru_exclude_ipv6" inet6 & _pids="$_pids $!"; }
                    load_user_ipset & _pids="$_pids $!"
                    [ -n "$_pids" ] && wait $_pids
                    unset _pids
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
                    rm -f "/tmp/xkeen_coldstart.lock"
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

# Активная проба готовности окружения вместо sleep $start_delay.
# Ждём ndmc, default route и insmod-ability xt_TPROXY (deps ndm
# подгружает асинхронно уже после ndmc-ready). $start_delay сохранён
# как safety cap (FAQ #12).
wait_for_ready() {
    _max=$(( ${start_delay:-60} * 2 ))
    _attempt=0
    _probe_ko="$directory_os_modules/xt_TPROXY.ko"
    while [ "$_attempt" -lt "$_max" ]; do
        if ndmc -c "show version" >/dev/null 2>&1 \
           && ip route show default 2>/dev/null | grep -q '^default'; then
            # .ko отсутствует (не TProxy/Hybrid), уже загружен, либо insmod удался
            if [ ! -f "$_probe_ko" ] \
               || grep -q '^xt_TPROXY ' /proc/modules 2>/dev/null \
               || insmod "$_probe_ko" >/dev/null 2>&1; then
                return 0
            fi
        fi
        usleep 500000
        _attempt=$((_attempt + 1))
    done
    return 0
}

# Остановка прокси-клиента
proxy_stop() {
    rm -f "/tmp/xkeen_ready"
    if ! proxy_status; then
        echo -e "  Прокси-клиент ${red}не запущен${reset}"
        cleanup_fd_monitor
    else
        [ -f "/tmp/xkeen_coldstart.lock" ] || log_info_router "Инициирована остановка прокси-клиента"
        cleanup_fd_monitor
        attempt=1
        while [ "$attempt" -le "$start_attempts" ]; do
            clean_firewall
            killall -q "$name_client" 2>/dev/null
            _stop_attempt=0
            while [ "$_stop_attempt" -lt 30 ]; do
                pidof "$name_client" >/dev/null 2>&1 || break
                _stop_attempt=$((_stop_attempt + 1))
                usleep 50000
            done
            unset _stop_attempt
            if pidof "$name_client" >/dev/null 2>&1; then
                killall -q -9 "$name_client" 2>/dev/null
                usleep 200000
            fi
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
            nohup "$0" cold_start >/dev/null 2>&1 &
            touch "/tmp/xkeen_coldstart.lock"
            exit 0
        fi
        proxy_start "$2"
    ;;
    stop) proxy_stop ;;
    status)
        if proxy_status; then
            mode_proxy=""
            if [ -f "$file_netfilter_hook" ]; then
                mode_proxy=$(grep '^mode_proxy=' "$file_netfilter_hook" | awk -F"=" '{print $2}' | tr -d "'" 2>/dev/null)
            fi
            [ -z "$mode_proxy" ] && mode_proxy="Other"
            echo -e "  Прокси-клиент ${yellow}$name_client${reset} ${green}запущен${reset} в режиме ${light_blue}$mode_proxy${reset}"
        else
            echo -e "  Прокси-клиент ${red}не запущен${reset}"
        fi
        ;;
    restart) proxy_stop; proxy_start "$2" ;;
    cold_start)
        # Re-spawn в чистый S05xkeen: sh-функции (wait_for_ready) не
        # наследуются через nohup sh -c, поэтому пробу зовём отсюда.
        wait_for_ready
        proxy_start ""
        ;;
    *) echo -e "  Команды: ${green}start${reset} | ${red}stop${reset} | ${yellow}restart${reset} | status" ;;
esac

exit 0