# Функция для получения информации о версии Mihomo и Yq
info_version_mihomo() {
    if [ "$mihomo_installed" = "installed" ]; then
        mihomo_current_version=$("$install_dir/mihomo" -v 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | cut -c2-)
    fi
}

info_version_yq() {
    if [ "$mihomo_installed" = "installed" ]; then
        yq_current_version=$("$install_dir/yq" -V 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | cut -c2-)
    fi
}
