# Удаление всех конфигураций xray

delete_configs() {
    find "$install_conf_dir" -name "*.json" -type f -delete
}
