# Функция для удаления файлов GeoIP данных
delete_geoip() {
    if [ "$chose_delete_geoip_antifilter_select" == "true" ]; then
        if [ -f "$geo_dir/geoip_antifilter.dat" ]; then
            rm "$geo_dir/geoip_antifilter.dat"
        fi
    fi

    if [ "$chose_delete_geoip_v2fly_select" == "true" ]; then
        if [ -f "$geo_dir/geoip_v2fly.dat" ]; then
            rm "$geo_dir/geoip_v2fly.dat"
        fi
    fi

    if [ "$chose_delete_geoip_zkeenip_select" == "true" ]; then
        rm -f "$geo_dir/zkeenip.dat" "$geo_dir/geoip_zkeenip.dat"
    fi
}

# Функция для удаления всех файлов GeoIP данных
delete_geoip_key() {
    if [ -f "$geo_dir/geoip_antifilter.dat" ]; then
        rm "$geo_dir/geoip_antifilter.dat"
    fi

    if [ -f "$geo_dir/geoip_v2fly.dat" ]; then
        rm "$geo_dir/geoip_v2fly.dat"
    fi

    rm -f "$geo_dir/zkeenip.dat" "$geo_dir/geoip_zkeenip.dat"
}
