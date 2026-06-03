# Функция для проверки установки Xray
info_xray() {
    if [ ! -x "$install_dir/xray" ] || ! "$install_dir/xray" version >/dev/null 2>&1; then
        xray_installed="not_installed"
    else
        xray_installed="installed"
    fi
}
