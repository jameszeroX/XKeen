# Функция для удаления cron задачи для GeoFile
delete_cron_geofile() {
    if [ -f "$cron_dir/$cron_file" ]; then
        tmp_file="$cron_dir/${cron_file}.tmp"
        
        cp "$cron_dir/$cron_file" "$tmp_file"
        
        grep -v "ug" "$tmp_file" | sed '/^\s*$/d' > "$cron_dir/$cron_file"
    fi
}
