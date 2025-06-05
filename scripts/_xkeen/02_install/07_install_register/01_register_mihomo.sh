# Регистрация Mihomo

register_mihomo() {
    if [ -f $install_dir/mihomo ]; then
        if [ ! -d /opt/etc/mihomo ]; then
            mkdir /opt/etc/mihomo
            cat << EOF > "/opt/etc/mihomo/config.yaml"
log-level: silent
allow-lan: false
ipv6: false
mode: rule
profile:
  store-selected: true
external-controller: 0.0.0.0:91
external-ui: ui
external-ui-url: "https://github.com/Zephyruso/zashboard/releases/latest/download/dist.zip"

listeners:
  - name: tproxy
    type: tproxy
    port: 4000
    
sniffer:
  enable: true
  parse-pure-ip: true
  sniff:
    HTTP:
      ports: [80]
    TLS:
      ports: [443]
  
proxies:
  - name: "vless-reality"
    type: vless
    server: ***.***.***.***
    port: 443
    uuid: *************************
    network: tcp
    packet-encoding: xudp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    servername: ********.com
    reality-opts:
      public-key: *****************
      short-id: ********
      support-x25519mlkem768: false
    client-fingerprint: chrome

  - name: direct
    type: direct

geox-url:
  geosite: "https://github.com/jameszeroX/zkeen-domains/releases/latest/download/zkeen.dat"

rules:
  - GEOSITE,domains,vless-reality
  - GEOSITE,other,vless-reality
  - GEOSITE,politic,vless-reality
  - GEOSITE,youtube,vless-reality
  - MATCH,direct
EOF
        fi
    fi
}


# Запрос на добавление ядра Mihomo

choice_add_mihomo() {
    while true; do
        echo
        echo
        echo -e "  ${green}Добавить${reset} ядро ${yellow}Mihomo${reset}?"
        echo
        echo "     1. Да"
        echo "     0. Нет"
        echo

        update_choices=$(input_digits "Ваш выбор: " "${red}Некорректный номер действия. ${reset}Пожалуйста, выберите снова")

        valid_input=true
        add_mihomo=true

        for choice in $update_choices; do
            if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
                echo -e "  ${red}Некорректный номер действия.${reset}"
                valid_input=false
                break
            fi
        done

        if ! $valid_input; then
            continue
        fi

        for choice in $update_choices; do
            case "$choice" in
                0)
                    add_mihomo=false
                    ;;
                1)
                    sleep 1
                    ;;
                *)
                    echo -e "  ${red}Некорректный номер действия.${reset}"
                    valid_input=false
                    break
                    ;;
            esac
        done

        if $valid_input; then
            break
        fi
    done
}