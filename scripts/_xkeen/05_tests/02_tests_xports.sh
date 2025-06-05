# Определение на каких портах слушает Xray
tests_ports_xray() {
    app_name="xray"
    listening_ports_tcp
    listening_ports_udp
    output="  Xray ${green}слушает${reset}"
    
    listening_ports_tcp=$(netstat -ltunp | grep "$app_name" | grep "tcp")
    listening_ports_udp=$(netstat -ltunp | grep "$app_name" | grep "udp")

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
                    protocol="${protocol} и UDP"
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
        echo -e "  $app_name ${red}не слушает${reset} на каких-либо портах"
    fi
	
	break
}
