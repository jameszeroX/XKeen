# Удаление всех конфигураций xray

delete_configs() {
    if [ -d "$install_conf_dir" ]; then
        find "$install_conf_dir" -name '*.json' -type f -delete
    fi
}
