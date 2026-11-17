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
        "jameszero" \
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
        "jameszero" \
        "A lightweight and portable command-line YAML, JSON, INI and XML processor."
}

register_yq_status() {
    write_opkg_status \
        "yq_s" \
        "$yq_current_version" \
        ""
}

add_mihomo_config() {
    if [ -f "$install_dir/mihomo" ]; then
        if [ -f "$mihomo_conf_dir/config.yaml" ]; then
            return 0
        elif [ ! -d "$mihomo_conf_dir" ]; then
            mkdir -p "$mihomo_conf_dir" || {
                echo -e "  ${red}Ошибка${reset}: Не удалось создать директорию конфигурации Mihomo $mihomo_conf_dir" >&2
                return 1
            }
        fi
        config_tmp="$mihomo_conf_dir/.config.yaml.tmp.$$"
        if ! cat > "$config_tmp" << EOF
find-process-mode: off # снижает нагрузку на роутер
# Не открывайте external-controller в LAN без secret — это полный контроль над ядром

listeners:
  - name: tproxy
    type: tproxy
    port: 1181
    udp: true

  - name: redir
    type: redir
    port: 1182

# Руководство по конфигурации Mihomo - https://wiki.metacubex.one/ru/config/
EOF
        then
            rm -f "$config_tmp"
            echo -e "  ${red}Ошибка${reset}: Не удалось записать шаблон конфигурации Mihomo" >&2
            return 1
        fi
        mv -f "$config_tmp" "$mihomo_conf_dir/config.yaml" || {
            rm -f "$config_tmp"
            echo -e "  ${red}Ошибка${reset}: Не удалось сохранить шаблон конфигурации Mihomo" >&2
            return 1
        }

        echo "  Добавлен шаблон конфигурационного файла Mihomo:"
        echo -e "  ${yellow}config.yaml${reset}"
        echo
        sleep 2
    fi
}
