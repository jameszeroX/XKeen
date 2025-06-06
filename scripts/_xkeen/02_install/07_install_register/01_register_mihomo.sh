# Регистрация Mihomo
register_mihomo() {
    if [ -f $install_dir/mihomo ]; then
        if [ -f "$mihomo_conf_dir/config.yaml" ]; then
            return 0
        elif [ ! -d $mihomo_conf_dir ]; then
            mkdir $mihomo_conf_dir
        fi
            cat << EOF > "$mihomo_conf_dir/config.yaml"
listeners:
  - name: tproxy
    type: tproxy
    port: 4000

mixed-port: 2080
allow-lan: true
mode: rule
log-level: silent 
ipv6: false
external-controller: 0.0.0.0:91
external-ui: ui
geodata-mode: true

profile:
  store-selected: true

sniffer:
  enable: true
  parse-pure-ip: true
  sniff:
    HTTP:
      ports: [80]
    TLS:
      ports: [443]

proxies:
  - name: PROXY
    type: vless
    server: ***.***.***.***
    port: 443
    uuid: ******-***-***-***-******
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

geox-url:
  geosite: "https://github.com/jameszeroX/zkeen-domains/releases/latest/download/zkeen.dat"

rules:
  - AND,((NETWORK,UDP),(DST-PORT,443)),REJECT
  - GEOSITE,DOMAINS,PROXY
  - GEOSITE,OTHER,PROXY
  - GEOSITE,POLITIC,PROXY
  - GEOSITE,YOUTUBE,PROXY
  - MATCH,DIRECT
EOF

        echo ""
        echo -e "  Добавлен шаблон кофигурационного файла mihomo:"
        echo -e "  ${yellow}config.yaml${reset}"
        sleep 2
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