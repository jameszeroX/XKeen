# Функция создания диагностического отчёта
diagnostic_process_snapshot() {
    local pids pid

    pids=$(pidof xray 2>/dev/null)
    pid=$(printf '%s\n' "$pids" | awk '{ for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+$/) { print $i; exit } }')
    if [ -n "$pid" ]; then
        name_client=xray
        diagnostic_pid="$pid"
        return 0
    fi

    pids=$(pidof mihomo 2>/dev/null)
    pid=$(printf '%s\n' "$pids" | awk '{ for (i=1; i<=NF; i++) if ($i ~ /^[0-9]+$/) { print $i; exit } }')
    if [ -n "$pid" ]; then
        name_client=mihomo
        diagnostic_pid="$pid"
        return 0
    fi
    return 1
}

diagnostic_process_stats() {
    local proc_dir fd_count limit
    proc_dir="${diagnostic_proc_root:-/proc}/$diagnostic_pid"
    if [ ! -d "$proc_dir" ]; then
        printf 'Процесс PID %s завершился во время диагностики\n' "$diagnostic_pid"
        return 0
    fi
    fd_count=$(ls "$proc_dir/fd" 2>/dev/null | wc -l | awk '{print $1}')
    limit=$(awk '/Max open files/ {print $4; exit}' "$proc_dir/limits" 2>/dev/null)
    printf 'Открыто файловых дескрипторов: %s\n' "${fd_count:-недоступно}"
    printf 'Лимит файловых дескрипторов: %s\n' "${limit:-недоступен}"
}

diagnostic() {
    # Установка пути к файлу diagnostic
    diagnostic="/opt/diagnostic.txt"

    if ! diagnostic_process_snapshot; then
        echo
        echo -e "  Диагностика возможна только при работающем ${yellow}XKeen${reset}"
        echo -e "  Запустите ${yellow}XKeen${reset} командой '${green}xkeen -start${reset}'"
        exit 1
    fi
    set_core_title "$name_client"

    ip4_supported=$(ip -4 addr show | grep -q "inet " && echo true || echo false)
    ip6_supported=$(check_ipv6_active && echo true || echo false)

    iptables_supported=$([ "$ip4_supported" = "true" ] && command -v iptables >/dev/null 2>&1 && echo true || echo false)
    ip6tables_supported=$([ "$ip6_supported" = "true" ] && command -v ip6tables >/dev/null 2>&1 && echo true || echo false)

    get_exclude_ip4() {
        [ "$iptables_supported" != "true" ] && return
        ipv4_eth=$(ip -o route get 77.88.8.8 2>/dev/null | sed -n 's/.*src \([^ ]*\).*/\1/p')
    }
    get_exclude_ip4

    get_exclude_ip6() {
        [ "$ip6tables_supported" != "true" ] && return
        ipv6_eth=$(ip -o -6 route get 2a02:6b8::feed:0ff 2>/dev/null | sed -n 's/.*src \([^ ]*\).*/\1/p')
    }
    get_exclude_ip6

    echo
    echo "  Выполняется диагностика. Пожалуйста, подождите..."

    # Очищаем файл diagnostic перед записью новых данных
    > "$diagnostic"
    chmod 600 "$diagnostic"

    # Функция записи заголовка
    write_header() {
        echo "-------------------------" >> "$diagnostic"
        echo -e "$1" >> "$diagnostic"
        echo "-------------------------" >> "$diagnostic"
        echo >> "$diagnostic"
    }

    # Функция логирования блоков
    log_block() {
        write_header "$1"
        cat >> "$diagnostic"
        echo >> "$diagnostic"; echo >> "$diagnostic"
    }

    # Функция маскировки чувствительных данных в proxy.sh
    mask_hook_sensitive_data() {
        sed -E -e "s/\b(rci_token)='[^']*'/\1='***MASKED***'/g"
    }

    mask_json_sensitive_data() {
        local masked
        if masked=$(jq -e --argjson keys "$1" '
            ($keys | map(ascii_downcase)) as $k
            | walk(if type == "object" then
                with_entries(
                    if (.key | ascii_downcase) as $n | any($k[]; . == $n)
                    then .value = "***MASKED***"
                    else . end)
              else . end)
        ' 2>/dev/null) && [ -n "$masked" ]; then
            printf '%s\n' "$masked"
        else
            printf '%s\n' '[Конфигурация скрыта: не удалось безопасно обработать данные]'
            return 1
        fi
    }

    # Функция маскировки чувствительных данных в xkeen.json
    mask_xkeen_sensitive_data() {
        strip_json_comments | mask_json_sensitive_data '["rci_token","gh_proxy","url","test_url"]'
    }

    # Функция маскировки чувствительных данных в конфигах Xray
    mask_xray_sensitive_data() {
        strip_json_comments | mask_json_sensitive_data '["id","uuid","address","host","publicKey","privateKey","password","user","pass","auth","encryption","secretKey","preSharedKey","dest","token","serverName","serverNames","sni","path","spiderX","shortId","shortIds","mldsa65Verify","mldsa65Seed","endpoint","authority","email"]'
    }

    # Функция маскировки чувствительных данных в конфиге Mihomo
    # shellcheck disable=SC2154
    mask_mihomo_sensitive_data() {
        local parsed
        if parsed=$("$install_dir/yq" -o=json '.' 2>/dev/null) && [ -n "$parsed" ]; then
            printf '%s\n' "$parsed" | mask_json_sensitive_data '["password","username","uuid","pre-shared-key","private-key","private-key-passphrase","server","servername","sni","host","query-server-name","external-controller","url","path","certificate","config","public-key","short-id","client-id","auth-str","obfs-password","encryption","token","secret","psk"]'
        else
            printf '%s\n' '[Конфигурация скрыта: не удалось безопасно обработать YAML]'
            return 1
        fi
    }

    # Функция маскировки пользовательских IP-адресов
    mask_ips() {
        local input
        local ipv4 ipv6

        # Если аргумент передан, обрабатываем его как строку
        if [ $# -gt 0 ]; then
            input="$*"
        else
            # Иначе читаем из stdin (для потоковой обработки)
            input=$(cat)
        fi

        ipv4=${ipv4_eth:-}
        ipv6=${ipv6_eth:-}
        printf '%s\n' "$input" | awk -v ipv4="$ipv4" -v ipv6="$ipv6" '
            function replace_ip(text, needle, replacement, v6, result, pos, before, after, left_ok, right_ok, n) {
                if (needle == "") return text
                n = length(needle)
                result = ""
                while ((pos = index(text, needle)) > 0) {
                    before = pos > 1 ? substr(text, pos - 1, 1) : ""
                    after = substr(text, pos + n, 1)
                    if (v6) {
                        left_ok = before == "" || before !~ /[[:alnum:]:.]/
                        right_ok = after == "" || after !~ /[[:alnum:]:.]/
                    } else {
                        left_ok = before == "" || before !~ /[[:alnum:]_.-]/
                        right_ok = after == "" || after !~ /[[:alnum:]_.-]/
                    }
                    result = result substr(text, 1, pos - 1)
                    if (left_ok && right_ok) {
                        result = result replacement
                        text = substr(text, pos + n)
                    } else {
                        result = result substr(text, pos, 1)
                        text = substr(text, pos + 1)
                    }
                }
                return result text
            }
            {
                line = $0
                line = replace_ip(line, ipv4, "***MASKED***", 0)
                if (ipv6 != "") {
                    line = replace_ip(line, "[" ipv6 "]", "[***MASKED***]", 0)
                    line = replace_ip(line, ipv6, "***MASKED***", 1)
                }
                print line
            }'
    }

    # Функция дампа iptables/ip6tables
    dump_tables() {
        local cmd="$1"
        local ver="$2"
        for chain in PREROUTING xkeen xkeen_force xkeen_divert xkeen_out OUTPUT; do
            $cmd -w -t nat -nvL "$chain" 2>&1 | mask_ips | log_block "Результат таблицы NAT цепи $chain $ver"
            $cmd -w -t mangle -nvL "$chain" 2>&1 | mask_ips | log_block "Результат таблицы MANGLE цепи $chain $ver"
        done
        $cmd -w -t mangle -nvL "xkeen_killswitch" 2>&1 | mask_ips | log_block "Результат таблицы MANGLE цепи xkeen_killswitch $ver"
        $cmd -w -t nat -nvL "_NDM_HOTSPOT_DNSREDIR" 2>&1 | mask_ips | log_block "Результат таблицы NAT цепи _NDM_HOTSPOT_DNSREDIR $ver"
    }

    # Сбор данных
    write_header "XKeen работает на ядре ${core_title}\nи установлен ${entware_storage}"

    {
        echo "Поддержка IPv4 - $ip4_supported"
        echo "Поддержка IPv6 - $ip6_supported"
        echo
        echo "Поддержка iptables - $iptables_supported"
        echo "Поддержка ip6tables - $ip6tables_supported"
    } | log_block "Доступность IPv4 и IPv6"

    [ "$iptables_supported" = "true" ] && dump_tables "iptables" "IPv4"
    [ "$ip6tables_supported" = "true" ] && dump_tables "ip6tables" "IPv6"

    if command -v ipset >/dev/null 2>&1; then
        sets=$(ipset list -n 2>/dev/null | grep -v '^_NDM_' | grep -v '^_UPNP')
        if [ -n "$sets" ]; then
            echo "$sets" | {
                total=0
                while read -r set; do
                    count=$(ipset save "$set" 2>/dev/null | grep -c '^add')
                    printf "%-30s %s\n" "$set" "$count"
                    total=$((total + count))
                done
                echo
                echo "Всего записей во всех списках: $total"
            } | log_block "Списки ipset и количество записей в каждом"
        fi
    fi

    xkeen_ndm="/opt/etc/ndm/netfilter.d/proxy.sh"

    if [ -f "$xkeen_ndm" ]; then
        write_header "Файл $xkeen_ndm"
        mask_hook_sensitive_data < "$xkeen_ndm" | mask_ips >> "$diagnostic"
        echo >> "$diagnostic"; echo >> "$diagnostic"
    fi

    curl_api "127.0.0.1:79/rci/ip/http/ssl" | jq -r '.port' | log_block "Проверка использования SSL порта"
    mask_ips "$(curl_api "127.0.0.1:79/rci/show/ip/policy" | jq -r '.[] | select(.description | ascii_downcase == "xkeen")')" | log_block "Данные о политике доступа"

    mask_ips "$(ip rule show)" | log_block "Результат команды ip rule show"
    mask_ips "$(ip route show table main)" | log_block "Результат команды ip route show table main"

    {
        curl_api "127.0.0.1:79/rci/show/version" | jq -r '.title, .model, .region'
        echo
        echo "Архитектура пакетов (opkg):"
        opkg print-architecture 2>/dev/null || echo "Команда opkg недоступна"
    } | log_block "Информация о роутере"

    {
        if [ "${name_client}" = "xray" ]; then xray version; else mihomo -v; fi
        echo
        echo "PID процесса: $diagnostic_pid"
        diagnostic_process_stats
    } | log_block "Версия $core_title и файловые дескрипторы"

    echo "XKeen $xkeen_current_version $xkeen_build (время сборки: $build_timestamp)" | log_block "Версия XKeen"

    if [ -f "$xkeen_config" ]; then
        write_header "Файл xkeen.json"
        mask_xkeen_sensitive_data < "$xkeen_config" >> "$diagnostic"
        echo >> "$diagnostic"; echo >> "$diagnostic"
    fi

    if [ "${name_client}" = "xray" ] && [ -d "$xray_conf_dir" ]; then
        ls -p "$xray_conf_dir" | log_block "Содержимое директории configs"

        for conf in dns inbounds routing outbounds; do
            file=$(ls "$xray_conf_dir"/*${conf}*.json 2>/dev/null | head -n 1)
            if [ -n "$file" ]; then
                write_header "Содержимое файла $file"
                mask_xray_sensitive_data < "$file" >> "$diagnostic"
                echo >> "$diagnostic"; echo >> "$diagnostic"
            fi
        done
    fi

    if [ "${name_client}" = "mihomo" ]; then
        for conf_file in "$mihomo_conf_dir/config.yaml" "$mihomo_conf_dir/config.yml"; do
            if [ -f "$conf_file" ]; then
                write_header "Содержимое файла $conf_file"
                mask_mihomo_sensitive_data < "$conf_file" >> "$diagnostic"
                echo >> "$diagnostic"; echo >> "$diagnostic"
            fi
        done
    fi

    echo
    echo -e "  Диагностика ${green}выполнена${reset}"
    echo -e "  Отправьте файл '${yellow}$diagnostic${reset}' в телеграм-чат ${yellow}XKeen${reset}, подробно описав возникшую проблему"
    echo
    echo -e "  ${red}Примечание${reset}: Диагностика не проверяет доступ к прокси-серверу, правильность заполнения конфигов"
    echo -e "  и настройки роутера/сервера. Она проверяет ${green}только${reset} корректность инициализации ${yellow}XKeen${reset} в роутере"
}
