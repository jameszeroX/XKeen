# Функция для удаления cron задачи для GeoFile
delete_cron_geofile() {
    if [ -f "$cron_dir/$cron_file" ]; then
        tmp_file="$cron_dir/${cron_file}.tmp"
        cp "$cron_dir/$cron_file" "$tmp_file"
        write_tmp="$cron_dir/${cron_file}.tmp.$$"
        grep -v "xkeen.*-ug" "$tmp_file" | grep -v '^[[:space:]]*$' > "$write_tmp"
        mv -f "$write_tmp" "$cron_dir/$cron_file" || rm -f "$write_tmp"
    fi
}
