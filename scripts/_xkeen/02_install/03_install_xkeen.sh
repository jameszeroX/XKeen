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

        # Unpack away from the live tree, verify, then replace directories
        # using the .old dance so interruption retains a usable installation.
        stage_dir="$install_dir/.xkeen.stage.$$"
        rm -rf "$stage_dir"
        mkdir -p "$stage_dir" || {
            echo -e "  ${red}Ошибка${reset}: Не удалось создать временный каталог для распаковки"
            rm -f "$xkeen_archive"
            return 1
        }
        if ! tar -xzf "$xkeen_archive" -C "$stage_dir" xkeen _xkeen \
            || [ ! -f "$stage_dir/xkeen" ] || [ ! -d "$stage_dir/_xkeen" ]; then
            echo -e "  ${red}Ошибка${reset}: В архиве XKeen нет ожидаемых xkeen/_xkeen"
            rm -rf "$stage_dir" "$xkeen_archive"
            return 1
        fi
        chmod +x "$stage_dir/xkeen"
        mv "$stage_dir/xkeen" "$install_dir/xkeen.new" || { rm -rf "$stage_dir"; return 1; }
        mv "$install_dir/xkeen.new" "$install_dir/xkeen" || { rm -rf "$stage_dir"; return 1; }
        rm -rf "$install_dir/.xkeen.old"
        [ -d "$install_dir/.xkeen" ] && mv "$install_dir/.xkeen" "$install_dir/.xkeen.old"
        if mv "$stage_dir/_xkeen" "$install_dir/.xkeen"; then
            rm -rf "$install_dir/.xkeen.old" "$stage_dir"
        else
            [ -d "$install_dir/.xkeen.old" ] && mv "$install_dir/.xkeen.old" "$install_dir/.xkeen"
            rm -rf "$stage_dir"
            return 1
        fi
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
