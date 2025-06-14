# Определение на каких портах слушает ядро прокси
tests_ports_client() {

    if pidof "xray" >/dev/null; then
        name_client=xray
    elif pidof "mihomo" >/dev/null; then
        name_client=mihomo
    else
        echo ""
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
        IFS=$'\n'
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
            
            if [[ "$line" == *::* ]]; then
                # IPv6 адрес
                gateway="::"
                port=$(echo "$line" | awk '{print $4}' | awk -F':' '{print $NF}')
            else
                # IPv4 адрес
                gateway=$(echo "$line" | awk '{print $4}' | cut -d':' -f1)
                port=$(echo "$line" | awk '{print $4}' | cut -d':' -f2)
            fi
            
            if [ "$printed" = false ]; then
                echo -e "$output"
                printed=true
            fi
            echo -e "\n     ${gray}Шлюз${reset} $gateway\n     ${gray}Порт${reset} $port\n     ${gray}Протокол${reset} $protocol"
        done
    else
        echo -e "  $name_client ${red}не слушает${reset} на каких-либо портах"
    fi

    break
}
