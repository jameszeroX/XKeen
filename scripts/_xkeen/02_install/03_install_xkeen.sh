# Функция для установки XKeen
install_xkeen() {
    xkeen_archive="$tmp_ram/xkeen.tar.gz"

    # Проверка наличия архива XKeen
    if [ -f "$xkeen_archive" ]; then
        # Валидация целостности архива
        if ! tar -tzf "$xkeen_archive" >/dev/null 2>&1; then
            echo -e "  ${red}Ошибка${reset}: Архив XKeen повреждён или имеет неверный формат"
            rm -f "$xkeen_archive"
            return 1
        fi

        # Распаковка во временный каталог, затем атомарная замена —
        # при обрыве не оставляем полузаписанный .xkeen поверх живой установки.
        _xk_extract="${tmp_ram}/xkeen_extract.$$"
        rm -rf "$_xk_extract"
        mkdir -p "$_xk_extract" || {
            echo -e "  ${red}Ошибка${reset}: Не удалось создать временный каталог для распаковки"
            rm -f "$xkeen_archive"
            return 1
        }

        if ! tar -xzf "$xkeen_archive" -C "$_xk_extract" xkeen _xkeen; then
            echo -e "  ${red}Ошибка${reset}: Не удалось распаковать архив XKeen"
            rm -rf "$_xk_extract" "$xkeen_archive"
            return 1
        fi

        if [ ! -f "$_xk_extract/xkeen" ] || [ ! -d "$_xk_extract/_xkeen" ]; then
            echo -e "  ${red}Ошибка${reset}: В архиве XKeen нет ожидаемых xkeen/_xkeen"
            rm -rf "$_xk_extract" "$xkeen_archive"
            return 1
        fi

        chmod +x "$_xk_extract/xkeen"
        mv -f "$_xk_extract/xkeen" "$install_dir/xkeen"
        rm -rf "$install_dir/.xkeen"
        mv "$_xk_extract/_xkeen" "$install_dir/.xkeen"
        rm -rf "$_xk_extract" "$xkeen_archive"
    fi
    [ -d "$log_dir/xkeen" ] && rm -rf "$log_dir/xkeen"
    return 0
}

check_keen_mode() {
    [ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" = "1" ] && return 0
    keen_mode="unsupported"
}

new_features() {
    if [ ! -d "$ipset_cfg" ]; then
        test_github
        smart_clear
        install_geoipset init

        if [ "$bypass_cron_geoipset" = "false" ] && [ "$info_update_geofile_cron" != "installed" ]; then
            smart_clear
            choice_update_cron
            update_cron_geofile_task
            smart_clear
            choice_cron_time
            install_cron
        fi
    fi
}
