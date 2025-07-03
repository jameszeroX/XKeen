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

    listening_ports_tcp=$(netstat -ltunp | grep "$name_client" | grep "tcp")
    listening_ports_udp=$(netstat -ltunp | grep "$name_client" | grep "udp")

    if [ -n "$listening_ports_tcp" ] || [ -n "$listening_ports_udp" ]; then
        printed=false
        IFS='
'
        for line in $listening_ports_tcp $listening_ports_udp; do
            gateway=""
            port=""
            protocol=""
            
            if [ -n "$(echo "$line" | grep "tcp")" ]; then
                protocol="TCP"
            fi
            if [ -n "$(echo "$line" | grep "udp")" ]; then
                if [ -n "$protocol" ]; then
                    protocol="$protocol и UDP"
                else
                    protocol="UDP"
                fi
            fi
            
            full_address=$(echo "$line" | awk '{print $4}')
            
            if echo "$full_address" | grep -q '^:::[0-9]'; then
                # Если IPv4 отображается как :::port
                gateway="0.0.0.0"
                port=$(echo "$full_address" | awk -F':::' '{print $2}')
            elif echo "$full_address" | grep -q '^\[::\]'; then
                # Явный IPv6 [::]:port
                gateway="[::]"
                port=$(echo "$full_address" | awk -F'\\]:' '{print $2}')
            elif echo "$full_address" | grep -q '\\]:'; then
                # Обычный IPv6 [addr]:port
                gateway=$(echo "$full_address" | awk -F'\\]:' '{print $1}')"]"
                port=$(echo "$full_address" | awk -F'\\]:' '{print $2}')
            elif echo "$full_address" | grep -q ':'; then
                # Обычный IPv4
                gateway=$(echo "$full_address" | cut -d':' -f1)
                port=$(echo "$full_address" | cut -d':' -f2)
            fi
            
            if [ "$printed" = false ]; then
                printf "%b\n" "$output"
                printed=true
            fi
            printf "\n     %bШлюз%b %s\n     %bПорт%b %s\n     %bПротокол%b %s\n" \
                   "$gray" "$reset" "$gateway" \
                   "$gray" "$reset" "$port" \
                   "$gray" "$reset" "$protocol"
        done
    else
        printf "%b\n" "  $name_client ${red}не слушает${reset} на каких-либо портах"
    fi
}