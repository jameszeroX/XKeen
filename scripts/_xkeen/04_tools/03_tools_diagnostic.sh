diagnostic() {
    # Установка пути к файлу diagnostic
    diagnostic="/opt/diagnostic.txt"

    if pidof "xray" >/dev/null; then
        name_client=xray
    elif pidof "mihomo" >/dev/null; then
        name_client=mihomo
    else
        echo
        echo -e "  Диагностика возможна только при работающем ${yellow}XKeen${reset}"
        echo -e "  Запустите ${yellow}XKeen${reset} командой '${green}xkeen -start${reset}'"
        exit 1
    fi

    ip4_supported=$(ip -4 addr show | grep -q "inet " && echo true || echo false)
    ip6_supported=$(ip -6 addr show | grep -q "inet6 fe80::" && echo true || echo false)

    iptables_supported=$([ "$ip4_supported" = "true" ] && command -v iptables >/dev/null 2>&1 && echo true || echo false)
    ip6tables_supported=$([ "$ip6_supported" = "true" ] && command -v ip6tables >/dev/null 2>&1 && echo true || echo false)

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

    # Функция маскировки чувствительных данных в конфигах Xray
    mask_xray_sensitive_data() {
        sed -E \
            -e 's/("(id|uuid|password|user|pass|auth|secretKey|preSharedKey)")[[:space:]]*:[[:space:]]*"?[^",[:space:]]+"?(,?)/\1: "***MASKED***"\3/g' \
            -e 's/("(address|host|serverName|sni|path|token|spiderX)")[[:space:]]*:[[:space:]]*"?[^",[:space:]]+"?(,?)/\1: "***MASKED***"\3/g' \
            -e 's/("(publicKey|privateKey|shortId|mldsa65Verify|encryption)")[[:space:]]*:[[:space:]]*"?[^",[:space:]]+"?(,?)/\1: "***MASKED***"\3/g'
    }

    # Функция маскировки чувствительных данных в конфигах Mihomo
    mask_mihomo_sensitive_data() {
        sed -E \
            -e 's/^([[:space:]]*(- )?(password|username|uuid|pre-shared-key|private-key|private-key-passphrase):).*/\1 ***MASKED***/i' \
            -e 's/^([[:space:]]*(- )?(server|servername|sni|host|query-server-name|external-controller):).*/\1 ***MASKED***/i' \
            -e 's/^([[:space:]]*(- )?(url|path|certificate|config|public-key|short-id|client-id|auth-str):).*/\1 ***MASKED***/i' \
            -e 's/^([[:space:]]*(- )?(obfs-password|encryption|token|secret|psk):).*/\1 ***MASKED***/i'
    }

    # Функция логирования файлов
    log_file() {
        local file="$1"
        local title="$2"
        if [ -f "$file" ]; then
            cat "$file" | log_block "$title"
        else
            echo "Файл $file не найден" | log_block "$title"
        fi
    }

    # Функция дампа iptables/ip6tables
    dump_tables() {
        local cmd="$1"
        local ver="$2"
        for chain in PREROUTING xkeen xkeen_out OUTPUT; do
            $cmd -w -t nat -nvL "$chain" 2>&1 | log_block "Результат таблицы NAT цепи $chain $ver"
            $cmd -w -t mangle -nvL "$chain" 2>&1 | log_block "Результат таблицы MANGLE цепи $chain $ver"
        done
        $cmd -w -t nat -nvL "_NDM_HOTSPOT_DNSREDIR" 2>&1 | log_block "Результат таблицы NAT цепи _NDM_HOTSPOT_DNSREDIR $ver"
    }

    # Сбор данных
    write_header "XKeen работает на ядре ${name_client}\nи установлен ${entware_storage}"

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

    log_file "/opt/etc/ndm/netfilter.d/proxy.sh" "Содержимое файла /opt/etc/ndm/netfilter.d/proxy.sh"

    curl -kfsS "localhost:79/rci/ip/http/ssl" | jq -r '.port' | log_block "Проверка использования SSL порта"
    curl -kfsS "localhost:79/rci/show/ip/policy" | jq -r '.[] | select(.description | ascii_downcase == "xkeen")' | log_block "Данные о политике доступа"
    
    ip rule show | log_block "Результат команды ip rule show"
    ip route show table main | log_block "Результат команды ip route show table main"
    
    curl -kfsS "localhost:79/rci/show/version" | jq -r '.title, .model, .region' | log_block "Данные из localhost:79/rci/show/version"

    {
        if [ "${name_client}" = "xray" ]; then xray version; else mihomo -v; fi
        echo
        echo "Открыто файловых дескрипторов:"
        ls "/proc/$(pidof ${name_client})/fd" | wc -l
        echo "Лимит файловых дескрипторов:"
        grep 'Max open files' "/proc/$(pidof ${name_client})/limits" | awk '{print $4}'
    } | log_block "Версия $name_client и файловые дескрипторы"

    echo "Версия XKeen $xkeen_current_version $xkeen_build (время сборки: $build_timestamp)" | log_block "Версия XKeen"

    [ -f "$xkeen_config" ] && log_file "$xkeen_config" "Файл xkeen.json"

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