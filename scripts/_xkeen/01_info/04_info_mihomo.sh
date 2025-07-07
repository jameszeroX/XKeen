# Функция для проверки установки Mihomo

info_mihomo() {
    if [ -f "$install_dir/mihomo" ] && [ -f "$install_dir/yq" ]; then
        mihomo_installed="installed"
    else
        mihomo_installed="not_installed"
    fi
}
