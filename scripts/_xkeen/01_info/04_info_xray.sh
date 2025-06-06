# Функция для проверки установки xray

info_xray() {
    if [ -e "$install_dir/xray" ]; then
        xray_installed="installed"
    else
        xray_installed="not_installed"
    fi
}
