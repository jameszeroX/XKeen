# Удаление всех конфигураций xray

delete_configs() {
    if [ -d "$install_conf_dir" ]; then
        find "$install_conf_dir" \( -name '*.json' -o -name '*.jsonc' \) -type f -delete
    fi
}
