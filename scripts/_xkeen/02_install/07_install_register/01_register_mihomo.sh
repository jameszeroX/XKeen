# Регистрация Mihomo
register_mihomo() {
    if [ -f $install_dir/mihomo ]; then
        if [ -f "$mihomo_conf_dir/config.yaml" ]; then
            return 0
        elif [ ! -d $mihomo_conf_dir ]; then
            mkdir $mihomo_conf_dir
        fi
            cat << EOF > "$mihomo_conf_dir/config.yaml"
tproxy-port: 1081
mixed-port: 1080
allow-lan: true
log-level: silent
geodata-mode: true
mode: rule
ipv6: false
external-ui: ui
external-controller: 0.0.0.0:9090

profile:
  store-selected: true

sniffer:
  enable: true
  parse-pure-ip: true
  sniff:
    HTTP:
    TLS:

proxies:
  - name: PROXY
    type: vless
    server: ***.***.***.***
    port: 443
    uuid: ******-***-***-***-******
    network: tcp
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
        echo "  Добавлен шаблон конфигурационного файла Mihomo:"
        echo -e "  ${yellow}config.yaml${reset}"
        sleep 2
    fi
}