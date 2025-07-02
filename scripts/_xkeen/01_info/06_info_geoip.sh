# Функция для проверки наличия и записи информации о базах GeoIP
info_geoip() {
    update_refilter_geoip=false
    update_v2fly_geoip=false
    update_zkeenip_geoip=false
    [ -f "$geo_dir/geoip_refilter.dat" ] && update_refilter_geoip=true
    [ -f "$geo_dir/geoip_v2fly.dat" ] && update_v2fly_geoip=true
    [ -f "$geo_dir/geoip_zkeenip.dat" ] || [ -f "$geo_dir/zkeenip.dat" ] && update_zkeenip_geoip=true
}