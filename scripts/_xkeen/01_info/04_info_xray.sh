# Функция для проверки установки Xray

info_xray() {
    if [ -f "$install_dir/xray" ]; then
        xray_installed="installed"
    else
        xray_installed="not_installed"
    fi
}
