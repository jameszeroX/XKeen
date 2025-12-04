# Функция для установки и обновления GeoSite
install_geosite() {
    mkdir -p "$geo_dir" || { echo "Ошибка: Не удалось создать директорию $geo_dir"; exit 1; }

    # Установка/обновление файла
    process_geosite_file() {
        url="$1"
        filename="$2"
        display_name="$3"
        update_flag="$4"

        temp_file=$(mktemp)
        min_size=24576  # 24 KB

        download() {
            curl --fail -m 10 -L -o "$temp_file" "$1" >/dev/null 2>&1
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

    # Установка GeoSite Re:filter
    if [ "$install_refilter_geosite" = "true" ] || [ "$update_refilter_geosite" = "true" ]; then
        process_geosite_file "$refilter_url" "geosite_refilter.dat" \
            "GeoSite Re:filter" "$update_refilter_geosite"
    fi

    # Установка GeoSite V2Fly
    if [ "$install_v2fly_geosite" = "true" ] || [ "$update_v2fly_geosite" = "true" ]; then
        process_geosite_file "$v2fly_url" "geosite_v2fly.dat" \
            "GeoSite V2Fly" "$update_v2fly_geosite"
    fi

    # Установка GeoSite ZKeen
    if [ "$install_zkeen_geosite" = "true" ] || [ "$update_zkeen_geosite" = "true" ]; then
        datfile="geosite_zkeen.dat"

        [ -L "$geo_dir/geosite_zkeen.dat" ] || [ -f "$geo_dir/zkeen.dat" ] && datfile="zkeen.dat"
        process_geosite_file "$zkeen_url" "$datfile" \
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
