# Функция для установки и обновления GeoIP
install_geoip() {
    mkdir -p "$geo_dir" || { echo "Ошибка: Не удалось создать директорию $geo_dir"; exit 1; }

    # Установка/обновление файла
    process_geoip_file() {
        url=$1
        filename=$2
        display_name=$3
        update_flag=$4

        temp_file=$(mktemp)
        
        # Первая попытка: прямая загрузка
        if curl -L -o "$temp_file" "$url" > /dev/null 2>&1; then
            if [ -s "$temp_file" ]; then
                mv "$temp_file" "$geo_dir/$filename"
                if [ "$update_flag" = true ]; then
                    echo -e "  $display_name ${green}успешно обновлен${reset}"
                else
                    echo -e "  $display_name ${green}успешно установлен${reset}"
                fi
                return 0
            else
                echo -e "  ${red}Неизвестная ошибка${reset} при установке $display_name"
                return 1
            fi
        else
            # Вторая попытка: загрузка через прокси
            if curl -L -o "$temp_file" "$gh_proxy/$url" > /dev/null 2>&1; then
                if [ -s "$temp_file" ]; then
                    mv "$temp_file" "$geo_dir/$filename"
                    if [ "$update_flag" = true ]; then
                        echo -e "  $display_name ${green}успешно обновлен через прокси${reset}"
                    else
                        echo -e "  $display_name ${green}успешно установлен через прокси${reset}"
                    fi
                    return 0
                else
                    echo -e "  ${red}Неизвестная ошибка${reset} при установке $display_name"
                    return 1
                fi
            else
                rm -f "$temp_file"
                echo -e "  ${red}Ошибка${reset} при загрузке $display_name. Проверьте соединение с интернетом или повторите позже"
                return 1
            fi
        fi
    }

    # Установка GeoIP Re:filter
    if [ "$install_refilter_geoip" = true ] || [ "$update_refilter_geoip" = true ]; then
        process_geoip_file \
            "$refilterip_url" \
            "geoip_refilter.dat" \
            "GeoIP Re:filter" \
            "$update_refilter_geoip"
    fi

    # Установка GeoIP V2Fly
    if [ "$install_v2fly_geoip" = true ] || [ "$update_v2fly_geoip" = true ]; then
        process_geoip_file \
            "$v2flyip_url" \
            "geoip_v2fly.dat" \
            "GeoIP V2Fly" \
            "$update_v2fly_geoip"
    fi

    # Установка GeoIP ZkeenIP
    if [ "$install_zkeenip_geoip" = true ] || [ "$update_zkeenip_geoip" = true ]; then
        datfile="geoip_zkeenip.dat"
        [ -L "$geo_dir/geoip_zkeenip.dat" ] && datfile="zkeenip.dat"
        process_geoip_file \
            "$zkeenip_url" \
            "$datfile" \
            "GeoIP ZkeenIP" \
            "$update_zkeenip_geoip"
        # Создание симлинков для совместимости
        if [ "$datfile" = "geoip_zkeenip.dat" ]; then
            rm -f "$geo_dir/zkeenip.dat"
            ln -sf "$geo_dir/geoip_zkeenip.dat" "$geo_dir/zkeenip.dat"
        elif [ "$datfile" = "zkeenip.dat" ]; then
            rm -f "$geo_dir/geoip_zkeenip.dat"
            ln -sf "$geo_dir/zkeenip.dat" "$geo_dir/geoip_zkeenip.dat"
        fi
    fi
}