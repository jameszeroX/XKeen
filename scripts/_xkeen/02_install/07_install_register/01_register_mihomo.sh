# Регистрация Mihomo
register_mihomo() {
    if [ -f $install_dir/mihomo ]; then
        if [ -f "$mihomo_conf_dir/config.yaml" ]; then
            return 0
        elif [ ! -d $mihomo_conf_dir ]; then
            mkdir $mihomo_conf_dir
        fi
            cat << EOF > "$mihomo_conf_dir/config.yaml"
tproxy-port: 1181
mixed-port: 1080
allow-lan: true
log-level: silent
geodata-mode: true
geo-auto-update: true
geo-update-interval: 72
find-process-mode: off
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
  geoip: "https://github.com/jameszeroX/zkeen-ip/releases/latest/download/zkeenip.dat"

rules:
  - AND,((NETWORK,UDP),(DST-PORT,443)),REJECT
  - GEOSITE,DOMAINS,PROXY
  - GEOSITE,OTHER,PROXY
  - GEOSITE,POLITIC,PROXY
  - GEOSITE,YOUTUBE,PROXY
  - GEOIP,AKAMAI,PROXY
  - GEOIP,AMAZON,PROXY
  - GEOIP,CDN77,PROXY
  - GEOIP,CLOUDFLARE,PROXY
  - GEOIP,DIGITALOCEAN,PROXY
  - GEOIP,FASTLY,PROXY
  - GEOIP,GCORE,PROXY
  - GEOIP,HETZNER,PROXY
  - GEOIP,LINODE,PROXY
  - GEOIP,OVH,PROXY
  - GEOIP,VULTR,PROXY
  - MATCH,DIRECT
EOF

        echo ""
        echo "  Добавлен шаблон конфигурационного файла Mihomo:"
        echo -e "  ${yellow}config.yaml${reset}"
        sleep 2
    fi
}