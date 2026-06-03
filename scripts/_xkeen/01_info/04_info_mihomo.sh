# Функция для проверки установки Mihomo

info_mihomo() {
    if [ ! -x "$install_dir/mihomo" ] || ! "$install_dir/mihomo" -v >/dev/null 2>&1 || \
       [ ! -x "$install_dir/yq" ] || ! "$install_dir/yq" -V >/dev/null 2>&1; then
        mihomo_installed="not_installed"
    else
        mihomo_installed="installed"
    fi
}