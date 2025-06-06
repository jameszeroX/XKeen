# Функция для установки задач Cron
install_cron() {
    cron_entry=""

    # Добавление задачи Cron для обновления GeoFile
    if [ -n "$choice_geofile_cron_time" ]; then
        cron_entry="$choice_geofile_cron_time $install_dir/xkeen -ug"
    fi

    # Если есть записи для задач Cron, то сохраняем их
    if [ -n "$cron_entry" ] || [ -n "$choice_canel_cron_select" ]; then
        cron_file_path="$cron_dir/$cron_file"

        touch "$cron_file_path"
        chmod +x "$cron_file_path"

        if [ -n "$cron_entry" ]; then
            grep -v "$install_dir/xkeen -ug" "$cron_file_path" > "$cron_file_path.tmp"
            mv "$cron_file_path.tmp" "$cron_file_path"
            printf "%s\n" "$cron_entry" >> "$cron_file_path"
        fi
        sed -i '/^$/d' "$cron_file_path"
    fi
}
