# Функция для получения версии Yq и её состояния (по образцу check_binary() из 04_register_init.sh:
# различает "бинарника нет" и "бинарник есть, но -V не дал распознаваемую версию")
info_version_yq() {
    if [ -x "$install_dir/yq" ]; then
        yq_current_version=$("$install_dir/yq" -V 2>&1 | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//' | head -1)

        if [ -n "$yq_current_version" ]; then
            yq_installed="installed"
        else
            yq_installed="broken"
            yq_current_version="unknown"
        fi
    else
        # shellcheck disable=SC2034 # yq_installed читается в scripts/xkeen
        yq_installed="not_installed"
        yq_current_version="unknown"
    fi
}

# Функция для проверки установки и получения версии Mihomo
info_mihomo() {
    info_version_yq

    if [ -x "$install_dir/mihomo" ]; then
        mihomo_current_version=$("$install_dir/mihomo" -v 2>&1 | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//' | head -1)

        if [ -n "$mihomo_current_version" ]; then
            mihomo_installed="installed"
        else
            mihomo_installed="not_installed"
            mihomo_current_version="unknown"
        fi
    else
        mihomo_installed="not_installed"
        mihomo_current_version="unknown"
    fi
}