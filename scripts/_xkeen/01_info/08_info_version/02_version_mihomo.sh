# Функции для получения информации о версиях Mihomo и Yq
info_version_mihomo() {
    if [ "$mihomo_installed" = "installed" ]; then
        mihomo_current_version=$("$install_dir/mihomo" -v 2>&1 | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//' | head -1)
        mihomo_current_version=${mihomo_current_version:-"unknown"}
    else
        mihomo_current_version="unknown"
    fi
}

info_version_yq() {
    if [ "$mihomo_installed" = "installed" ]; then
        yq_current_version=$("$install_dir/yq" -V 2>&1 | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//' | head -1)
        yq_current_version=${yq_current_version:-"unknown"}
    else
        yq_current_version="unknown"
    fi
}
