# Регистрация Mihomo

register_mihomo_list() {
    cd "$register_dir/" || exit
    touch mihomo_s.list
    echo "/opt/sbin/mihomo" >> mihomo_s.list
    echo "/opt/etc/mihomo/config.yaml" >> mihomo_s.list
    echo "/opt/etc/mihomo" >> mihomo_s.list
}

register_mihomo_control() {

    cat << EOF > "$register_dir/mihomo_s.control"
Package: mihomo_s
Version: $mihomo_current_version
Depends: yq_s
Source: MetaCubeX
SourceName: mihomo_s
Section: net
SourceDateEpoch: $source_date_epoch
Maintainer: jameszero
Architecture: $status_architecture
Installed-Size: $installed_size
Description: A unified platform for anti-censorship.
EOF
}

register_mihomo_status() {
    # Генерация новой записи
    echo "Package: mihomo_s" > new_entry.txt
    echo "Version: $mihomo_current_version" >> new_entry.txt
    echo "Depends: yq_s" >> new_entry.txt
    echo "Status: install user installed" >> new_entry.txt
    echo "Architecture: $status_architecture" >> new_entry.txt
    echo "Installed-Time: $(date +%s)" >> new_entry.txt

    # Чтение существующего содержимого файла "status"
    existing_content=$(cat "$status_file")

    # Объединение существующего содержимого и новой записи
    echo -e "\n$(cat new_entry.txt)" >> "$status_file"
}

register_yq_list() {
    cd "$register_dir/" || exit
    touch yq_s.list
    echo "/opt/sbin/yq" >> yq_s.list
}

register_yq_control() {

    cat << EOF > "$register_dir/yq_s.control"
Package: yq_s
Version: $yq_current_version
Source: mikefarah
SourceName: yq_s
Section: net
SourceDateEpoch: $source_date_epoch
Maintainer: jameszero
Architecture: $status_architecture
Installed-Size: $installed_size
Description: A lightweight and portable command-line YAML, JSON, INI and XML processor.
EOF
}

register_yq_status() {
    # Генерация новой записи
    echo "Package: yq_s" > new_entry.txt
    echo "Version: $yq_current_version" >> new_entry.txt
    echo "Status: install user installed" >> new_entry.txt
    echo "Architecture: $status_architecture" >> new_entry.txt
    echo "Installed-Time: $(date +%s)" >> new_entry.txt

    # Чтение существующего содержимого файла "status"
    existing_content=$(cat "$status_file")

    # Объединение существующего содержимого и новой записи
    echo -e "\n$(cat new_entry.txt)" >> "$status_file"
}

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
    servername: ********.***
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
  - GEOIP,ORACLE,PROXY
  - GEOIP,OVH,PROXY
  - GEOIP,VULTR,PROXY
  - MATCH,DIRECT
EOF

        echo
        echo "  Добавлен шаблон конфигурационного файла Mihomo:"
        echo -e "  ${yellow}config.yaml${reset}"
        sleep 2
    fi
}