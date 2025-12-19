# Функция для установки и обновления GeoIP
install_geoip() {
    mkdir -p "$geo_dir" || { echo "Ошибка: Не удалось создать директорию $geo_dir"; exit 1; }

    # Установка/обновление файла
    process_geoip_file() {
        url="$1"
        filename="$2"
        display_name="$3"
        update_flag="$4"

        temp_file=$(mktemp)
        min_size=24576  # 24 KB

        download() {
            curl --connect-timeout 10 -m 60 -fL -o "$temp_file" "$1" >/dev/null 2>&1
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
        actual_size=$(wc -c < "$temp_file")
        if [ "$actual_size" -lt "$min_size" ]; then
            printf "  ${red}Ошибка${reset}: загруженный файл слишком мал (%s bytes) или повреждён\n  Невозможно обновить. Оставляем старый файл\n\n" "$actual_size"
            rm -f "$temp_file"
            return 1
        fi

        # Проверка на HTML
        grep -qi "<html" "$temp_file"
        if [ $? -eq 0 ]; then
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

    # Установка GeoIP Re:filter
    if [ "$install_refilter_geoip" = "true" ] || [ "$update_refilter_geoip" = "true" ]; then
        process_geoip_file "$refilterip_url" "geoip_refilter.dat" \
            "GeoIP Re:filter" "$update_refilter_geoip"
    fi

    # Установка GeoIP V2Fly
    if [ "$install_v2fly_geoip" = "true" ] || [ "$update_v2fly_geoip" = "true" ]; then
        process_geoip_file "$v2flyip_url" "geoip_v2fly.dat" \
            "GeoIP V2Fly" "$update_v2fly_geoip"
    fi

    # Установка GeoIP ZKeenIP
    if [ "$install_zkeenip_geoip" = "true" ] || [ "$update_zkeenip_geoip" = "true" ]; then
        datfile="geoip_zkeenip.dat"
        [ -L "$geo_dir/geoip_zkeenip.dat" ] || [ -f "$geo_dir/zkeenip.dat" ] && datfile="zkeenip.dat"
        process_geoip_file "$zkeenip_url" "$datfile" \
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
