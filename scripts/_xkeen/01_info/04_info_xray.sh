# Функция для проверки установки Xray

info_xray() {
    if [ -x "$install_dir/xray" ]; then
        xray_installed="installed"
    else
        xray_installed="not_installed"
    fi
}
