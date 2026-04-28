# Удаление всех конфигураций Xray

delete_configs() {
    if [ -d "$xray_conf_dir" ]; then
        find "$xray_conf_dir" -maxdepth 1 -name '*.json' -type f -delete
    fi
}
