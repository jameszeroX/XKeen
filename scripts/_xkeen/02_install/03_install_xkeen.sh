# Функция для установки XKeen
install_xkeen() {
    xkeen_archive="$ktmp_dir/xkeen.tar.gz"

    # Проверка наличия архива XKeen
    if [ -f "$xkeen_archive" ]; then
        # Распаковка архива
        tar -xzf "$xkeen_archive" -C "$install_dir" xkeen _xkeen

        # Проверка наличия _xkeen в install_dir и его перемещение
        if [ -d "$install_dir/_xkeen" ]; then
            rm -rf "$install_dir/.xkeen"
            mv "$install_dir/_xkeen" "$install_dir/.xkeen"
        else
            echo -e "  ${red}Ошибка${reset}: _xkeen не была правильно перенесена"
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
