# Функция для проверки установки Mihomo

info_mihomo() {
    if [ -x "$install_dir/mihomo" ] && [ -x "$install_dir/yq" ]; then
        mihomo_installed="installed"
    else
        mihomo_installed="not_installed"
    fi
}
