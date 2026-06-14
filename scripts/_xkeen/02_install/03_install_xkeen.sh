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

        # Распаковка архива
        tar -xzf "$xkeen_archive" -C "$install_dir" xkeen _xkeen

        # Проверка наличия _xkeen в install_dir и его перемещение
        if [ -d "$install_dir/_xkeen" ]; then
            rm -rf "$install_dir/.xkeen"
            mv "$install_dir/_xkeen" "$install_dir/.xkeen"
        else
            echo -e "  ${red}Ошибка${reset}: _xkeen не была правильно перенесена"
            rm -f "$xkeen_archive"
            return 1
        fi

        # Удаление архива
        rm "$xkeen_archive"
    fi
    [ -d "$log_dir/xkeen" ] && rm -rf "$log_dir/xkeen"
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
    fi
}