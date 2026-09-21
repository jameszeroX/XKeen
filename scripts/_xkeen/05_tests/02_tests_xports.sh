# Определение на каких портах слушает ядро прокси
tests_ports_client() {

    if pidof "xray" >/dev/null; then
        name_client=xray
    elif pidof "mihomo" >/dev/null; then
        name_client=mihomo
    else
        echo
        echo "  Определение портов прослушивания возможно только при работающем XKeen"
        echo "  Запустите XKeen командой 'xkeen -start'"
        exit 1
    fi

    listening_ports_tcp=
    listening_ports_udp=
    output="  $name_client ${green}слушает${reset}"

    netstat_raw=$(netstat -ltunp 2>/dev/null | grep "$name_client")
    listening_ports_tcp=$(printf '%s\n' "$netstat_raw" | grep "tcp")
    listening_ports_udp=$(printf '%s\n' "$netstat_raw" | grep "udp")

    if [ -n "$listening_ports_tcp" ] || [ -n "$listening_ports_udp" ]; then
        printed=false
        local IFS='
'
        for line in $listening_ports_tcp $listening_ports_udp; do
            gateway=
            port=
            protocol=

            case "$line" in
                tcp*) protocol="TCP" ;;
            esac
            case "$line" in
                udp*)
                    if [ -n "$protocol" ]; then
                        protocol="$protocol и UDP"
                    else
                        protocol="UDP"
                    fi
                    ;;
            esac

            # Разбор шлюза и порта одним awk-вызовом: field 4 netstat-строки
            # покрывает форматы 0.0.0.0:port, :::port, [::]:port, [addr]:port, addr:port
            gateway_port=$(printf '%s\n' "$line" | awk '{
                addr = $4
                if (addr ~ /^:::[0-9]/) {
                    # Если IPv4 отображается как :::port
                    gw = "0.0.0.0"
                    sub(/^:::/, "", addr)
                    pt = addr
                } else if (addr ~ /^\[::\]:/) {
                    # Явный IPv6 [::]:port
                    gw = "[::]"
                    sub(/^\[::\]:/, "", addr)
                    pt = addr
                } else if (addr ~ /^\[.*\]:/) {
                    # Обычный IPv6 [addr]:port
                    n = index(addr, "]:")
                    gw = substr(addr, 1, n)
                    pt = substr(addr, n + 2)
                } else if (addr ~ /:/) {
                    # Обычный IPv4
                    n = index(addr, ":")
                    gw = substr(addr, 1, n - 1)
                    pt = substr(addr, n + 1)
                } else {
                    gw = ""
                    pt = ""
                }
                print gw, pt
            }')
            gateway=${gateway_port%% *}
            port=${gateway_port#* }

            if [ "$printed" = false ]; then
                printf "%b\n" "$output"
                printed=true
            fi
            printf "\n     %bШлюз%b %s\n     %bПорт%b %s\n     %bПротокол%b %s\n" \
                   "$italic" "$reset" "$gateway" \
                   "$italic" "$reset" "$port" \
                   "$italic" "$reset" "$protocol"
        done
    else
        printf "%b\n" "  $name_client ${red}не слушает${reset} на каких-либо портах"
    fi
}