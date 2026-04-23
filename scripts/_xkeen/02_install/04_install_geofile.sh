# Функция для загрузки и обработки геофайлов
process_geo_file() {
    local url="$1"
    local filename="$2"
    local display_name="$3"
    local update_flag="$4"

    # Защита от path traversal
    if case "$filename" in */*|*\\*|..|.) true;; *) false;; esac; then
        printf "  ${red}Ошибка${reset}: Недопустимое имя файла %s (path traversal)\n" "$filename"
        return 1
    fi

    test_github

    mkdir -p "$tmp_dir"
    local temp_file=$(mktemp "$tmp_dir/geo.XXXXXX")
    local min_size=24576  # 24 KB

    download() {
        curl --connect-timeout 10 $curl_timeout -fL -o "$temp_file" "$1" >/dev/null 2>&1
        return $?
    }

    printf "  Загрузка %s...\n" "$display_name"

    if [ "$use_direct" = "true" ]; then
        :
    else
        url="$gh_proxy/$url"
    fi

    download "$url"
    if [ $? -eq 0 ]; then
        :
    else
        rm -f "$temp_file"
        printf "  ${red}Ошибка${reset}: не удалось загрузить %s\n" "$display_name"
        return 1
    fi

    # Проверка размера файла
    local actual_size=$(wc -c < "$temp_file")
    if [ "$actual_size" -lt "$min_size" ]; then
        printf "  ${red}Ошибка${reset}: загруженный файл слишком мал (%s bytes) или повреждён\n  Невозможно обновить. Оставляем старый файл\n\n" "$actual_size"
        rm -f "$temp_file"
        return 1
    fi

    # Проверка на HTML
    if grep -qi "<html" "$temp_file"; then
        printf "  ${red}Ошибка${reset}: получена HTML-страница вместо dat-файла\n  Невозможно обновить. Оставляем старый файл\n\n"
        rm -f "$temp_file"
        return 1
    fi

    # Безопасная замена
    if mv "$temp_file" "$geo_dir/$filename.new"; then
        mv -f "$geo_dir/$filename.new" "$geo_dir/$filename"
    fi

    if [ "$update_flag" = "true" ]; then
        printf "  %s ${green}успешно обновлён${reset}\n\n" "$display_name"
    else
        printf "  %s ${green}успешно установлен${reset}\n\n" "$display_name"
    fi

    return 0
}

# Функция для установки и обновления GeoSite
install_geosite() {
    mkdir -p "$geo_dir" || { echo "Ошибка: Не удалось создать директорию $geo_dir"; exit 1; }

    # Установка GeoSite Re:filter
    if [ "$install_refilter_geosite" = "true" ] || [ "$update_refilter_geosite" = "true" ]; then
        process_geo_file "$refilter_url" "geosite_refilter.dat" \
            "GeoSite Re:filter" "$update_refilter_geosite"
    fi

    # Установка GeoSite V2Fly
    if [ "$install_v2fly_geosite" = "true" ] || [ "$update_v2fly_geosite" = "true" ]; then
        process_geo_file "$v2fly_url" "geosite_v2fly.dat" \
            "GeoSite V2Fly" "$update_v2fly_geosite"
    fi

    # Установка GeoSite ZKeen
    if [ "$install_zkeen_geosite" = "true" ] || [ "$update_zkeen_geosite" = "true" ]; then
        local datfile="geosite_zkeen.dat"

        if [ -L "$geo_dir/geosite_zkeen.dat" ]; then
            datfile="zkeen.dat"
        elif [ -L "$geo_dir/zkeen.dat" ]; then
            datfile="geosite_zkeen.dat"
        elif [ -f "$geo_dir/zkeen.dat" ] && ! [ -f "$geo_dir/geosite_zkeen.dat" ]; then
            datfile="zkeen.dat"
        fi

        process_geo_file "$zkeen_url" "$datfile" \
            "GeoSite ZKeen" "$update_zkeen_geosite"

        # Создание симлинков для совместимости
        if [ "$datfile" = "geosite_zkeen.dat" ]; then
            rm -f "$geo_dir/zkeen.dat"
            ln -sf "$geo_dir/geosite_zkeen.dat" "$geo_dir/zkeen.dat"
        else
            rm -f "$geo_dir/geosite_zkeen.dat"
            ln -sf "$geo_dir/zkeen.dat" "$geo_dir/geosite_zkeen.dat"
        fi
    fi
}

# Функция для установки и обновления GeoIP
install_geoip() {
    mkdir -p "$geo_dir" || { echo "Ошибка: Не удалось создать директорию $geo_dir"; exit 1; }

    # Установка GeoIP Re:filter
    if [ "$install_refilter_geoip" = "true" ] || [ "$update_refilter_geoip" = "true" ]; then
        process_geo_file "$refilterip_url" "geoip_refilter.dat" \
            "GeoIP Re:filter" "$update_refilter_geoip"
    fi

    # Установка GeoIP V2Fly
    if [ "$install_v2fly_geoip" = "true" ] || [ "$update_v2fly_geoip" = "true" ]; then
        process_geo_file "$v2flyip_url" "geoip_v2fly.dat" \
            "GeoIP V2Fly" "$update_v2fly_geoip"
    fi

    # Установка GeoIP ZKeenIP
    if [ "$install_zkeenip_geoip" = "true" ] || [ "$update_zkeenip_geoip" = "true" ]; then
        local datfile="geoip_zkeenip.dat"

        if [ -L "$geo_dir/geoip_zkeenip.dat" ]; then
            datfile="zkeenip.dat"
        elif [ -L "$geo_dir/zkeenip.dat" ]; then
            datfile="geoip_zkeenip.dat"
        elif [ -f "$geo_dir/zkeenip.dat" ] && ! [ -f "$geo_dir/geoip_zkeenip.dat" ]; then
            datfile="zkeenip.dat"
        fi

        process_geo_file "$zkeenip_url" "$datfile" \
            "GeoIP ZKeenIP" "$update_zkeenip_geoip"

        # Создание симлинков для совместимости
        if [ "$datfile" = "geoip_zkeenip.dat" ]; then
            rm -f "$geo_dir/zkeenip.dat"
            ln -sf "$geo_dir/geoip_zkeenip.dat" "$geo_dir/zkeenip.dat"
        else
            rm -f "$geo_dir/geoip_zkeenip.dat"
            ln -sf "$geo_dir/zkeenip.dat" "$geo_dir/geoip_zkeenip.dat"
        fi
    fi
}