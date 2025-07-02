# Функция для удаления выбранных файлов GeoIP
delete_geoip() {
    [ "$choice_delete_geoip_refilter_select" = "true" ] && rm -f "$geo_dir/geoip_refilter.dat"
    [ "$choice_delete_geoip_v2fly_select" = "true" ] && rm -f "$geo_dir/geoip_v2fly.dat"
    [ "$choice_delete_geoip_zkeen_select" = "true" ] && rm -f "$geo_dir/"geoip_zkeenip.dat "$geo_dir/"zkeenip.dat
}

# Функция для удаления всех файлов GeoIP
delete_geoip_key() {
    rm -f "$geo_dir/geoip_refilter.dat" \
          "$geo_dir/geoip_v2fly.dat" \
          "$geo_dir/geoip_zkeenip.dat" \
          "$geo_dir/zkeenip.dat"
}