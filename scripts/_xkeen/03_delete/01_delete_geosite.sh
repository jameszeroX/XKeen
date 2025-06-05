# Функция для удаления файлов GeoSite
delete_geosite() {
    if [ "$chose_delete_geosite_antifilter_select" == "true" ]; then
        if [ -f "$geo_dir/geosite_antifilter.dat" ]; then
            rm "$geo_dir/geosite_antifilter.dat"
        fi
    fi

    if [ "$chose_delete_geosite_v2fly_select" == "true" ]; then
        if [ -f "$geo_dir/geosite_v2fly.dat" ]; then
            rm "$geo_dir/geosite_v2fly.dat"
        fi
    fi
	
	if [ "$chose_delete_geosite_zkeen_select" == "true" ]; then
            rm -f "$geo_dir/zkeen.dat" "$geo_dir/geosite_zkeen.dat"
    fi
}

# Функция для удаления всех файлов GeoSite
delete_geosite_key() {  
    if [ -f "$geo_dir/geosite_antifilter.dat" ]; then
        rm "$geo_dir/geosite_antifilter.dat"
    fi

    if [ -f "$geo_dir/geosite_v2fly.dat" ]; then
        rm "$geo_dir/geosite_v2fly.dat"
    fi
	
    rm -f "$geo_dir/zkeen.dat" "$geo_dir/geosite_zkeen.dat"
}
