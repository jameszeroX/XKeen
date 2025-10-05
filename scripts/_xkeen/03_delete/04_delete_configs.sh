# Удаление всех конфигураций Xray

delete_configs() {
    if [ -d "$install_conf_dir" ]; then
        find "$install_conf_dir" -name '*.json' -type f -delete
    fi
}
