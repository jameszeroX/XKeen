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