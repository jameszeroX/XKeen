# Функция для проверки наличия и записи информации о базах GeoSite
info_geosite() {
    update_refilter_geosite=false
    update_v2fly_geosite=false
    update_zkeen_geosite=false
    [ -f "$geo_dir/geosite_refilter.dat" ] && update_refilter_geosite=true
    [ -f "$geo_dir/geosite_v2fly.dat" ] && update_v2fly_geosite=true
    [ -f "$geo_dir/geosite_zkeen.dat" ] || [ -f "$geo_dir/zkeen.dat" ] && update_zkeen_geosite=true
}

