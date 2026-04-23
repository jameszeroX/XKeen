# Регистрация Mihomo

register_mihomo_list() {
    cd "$register_dir/" || exit
    touch mihomo_s.list
    echo "/opt/sbin/mihomo" >> mihomo_s.list
    echo "/opt/etc/mihomo/config.yaml" >> mihomo_s.list
    echo "/opt/etc/mihomo" >> mihomo_s.list
}

register_mihomo_control() {
    write_opkg_control \
        "mihomo_s" \
        "$mihomo_current_version" \
        "yq_s" \
        "MetaCubeX" \
        "mihomo_s" \
        "jameszero / levmnkv" \
        "A unified platform for anti-censorship."
}

register_mihomo_status() {
    write_opkg_status \
        "mihomo_s" \
        "$mihomo_current_version" \
        "yq_s"
}

register_yq_list() {
    cd "$register_dir/" || exit
    touch yq_s.list
    echo "/opt/sbin/yq" >> yq_s.list
}

register_yq_control() {
    write_opkg_control \
        "yq_s" \
        "$yq_current_version" \
        "" \
        "mikefarah" \
        "yq_s" \
        "jameszero / levmnkv" \
        "A lightweight and portable command-line YAML, JSON, INI and XML processor."
}

register_yq_status() {
    write_opkg_status \
        "yq_s" \
        "$yq_current_version" \
        ""
}

add_mihomo_config() {
    if [ -f $install_dir/mihomo ]; then
        if [ -f "$mihomo_conf_dir/config.yaml" ]; then
            return 0
        elif [ ! -d $mihomo_conf_dir ]; then
            mkdir $mihomo_conf_dir
        fi
            cat << EOF > "$mihomo_conf_dir/config.yaml"
tproxy-port: 1181
redir-port: 1182
# Руководство по конфигурации Mihomo - https://wiki.metacubex.one/ru/config/
EOF

        echo
        echo "  Добавлен шаблон конфигурационного файла Mihomo:"
        echo -e "  ${yellow}config.yaml${reset}"
        sleep 2
    fi
}
