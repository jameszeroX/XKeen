# Функция для проверки наличия и записи информации о базах geoip
info_geoip() {
    # Проверяем наличие файла geoip_antifilter.dat
    if [ -e "$geo_dir/geoip_antifilter.dat" ]; then
        geo_exists_geoip_antifilter="installed"
    else
        geo_exists_geoip_antifilter="not_installed"
    fi

    # Проверяем наличие файла geoip_v2fly.dat
    if [ -e "$geo_dir/geoip_v2fly.dat" ]; then
        geo_exists_geoip_v2fly="installed"
    else
        geo_exists_geoip_v2fly="not_installed"
    fi

    # Проверяем наличие файла geoip_zkeenip.dat
    if [ -e "$geo_dir/geoip_zkeenip.dat" ]; then
        geo_exists_geoip_zkeenip="installed"
    else
        geo_exists_geoip_zkeenip="not_installed"
    fi
}
