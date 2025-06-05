# Функция для установки задач Cron
install_cron() {
    cron_entry=""

    # Добавление задачи Cron для обновления GeoFile
    if [ -n "$chose_geofile_cron_time" ]; then
        cron_entry="$cron_entry\n$chose_geofile_cron_time $install_dir/xkeen -ug"
    fi

    # Если есть записи для задач Cron, то сохраняем их
    if [ -n "$cron_entry" ] || [ -n "$chose_canel_cron_select" ]; then
        cron_file_path="$cron_dir/$cron_file"

        touch "$cron_file_path"
        chmod +x "$cron_file_path"
        echo -e "$cron_entry" >> "$cron_file_path"
    fi
}
