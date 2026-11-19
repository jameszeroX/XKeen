# Функция для установки задач Cron
install_cron() {
    local cron_file_path cron_tmp
    cron_entry=

    # Добавление задачи Cron для обновления GeoFile
    if [ -n "$choice_geofile_cron_time" ]; then
        cron_entry="$choice_geofile_cron_time $install_dir/xkeen -ug"
    fi

    # Пустой/отменённый выбор не должен переписывать пользовательский crontab.
    if [ -n "$cron_entry" ]; then
        cron_file_path="$cron_dir/$cron_file"
        cron_tmp="${cron_file_path}.tmp.$$"
        mkdir -p "$cron_dir" || return 1
        if [ -f "$cron_file_path" ]; then
            awk -v exe="$install_dir/xkeen" 'NF < 7 || $6 != exe || $7 != "-ug"' "$cron_file_path" > "$cron_tmp" || {
                rm -f "$cron_tmp"
                return 1
            }
        else
            : > "$cron_tmp" || return 1
        fi
        printf "%s\n" "$cron_entry" >> "$cron_tmp" || {
            rm -f "$cron_tmp"
            return 1
        }
        chmod +x "$cron_tmp" && sed -i '/^$/d' "$cron_tmp" && mv -f "$cron_tmp" "$cron_file_path" || {
            rm -f "$cron_tmp"
            return 1
        }
    fi
}
