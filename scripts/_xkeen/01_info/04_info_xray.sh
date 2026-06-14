# Функция для проверки установки и получения версии Xray
info_xray() {
    if [ -x "$install_dir/xray" ]; then
        xray_current_version=$("$install_dir/xray" version 2>&1 | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//' | head -1)

        if [ -n "$xray_current_version" ]; then
            xray_installed="installed"
        else
            xray_installed="not_installed"
            xray_current_version="unknown"
        fi
    else
        xray_installed="not_installed"
        xray_current_version="unknown"
    fi
}