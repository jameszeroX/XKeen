# Функция для установки и обновления GeoSite
install_geosite() {
    mkdir -p "$geo_dir" || { echo "Ошибка: Не удалось создать директорию $geo_dir"; exit 1; }

    # Установка/обновление файла
    process_geosite_file() {
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

    # Установка GeoSite Re:filter
    if [ "$install_refilter_geosite" = true ] || [ "$update_refilter_geosite" = true ]; then
        process_geosite_file \
            "$refilter_url" \
            "geosite_refilter.dat" \
            "GeoSite Re:filter" \
            "$update_refilter_geosite"
    fi

    # Установка GeoSite V2Fly
    if [ "$install_v2fly_geosite" = true ] || [ "$update_v2fly_geosite" = true ]; then
        process_geosite_file \
            "$v2fly_url" \
            "geosite_v2fly.dat" \
            "GeoSite V2Fly" \
            "$update_v2fly_geosite"
    fi

    # Установка GeoSite ZKeen
    if [ "$install_zkeen_geosite" = true ] || [ "$update_zkeen_geosite" = true ]; then
        datfile="geosite_zkeen.dat"
        [ -L "$geo_dir/geosite_zkeen.dat" ] && datfile="zkeen.dat"
        process_geosite_file \
            "$zkeen_url" \
            "$datfile" \
            "GeoSite ZKeen" \
            "$update_zkeen_geosite"
        # Создание симлинков для совместимости
        if [ "$datfile" = "geosite_zkeen.dat" ]; then
            rm -f "$geo_dir/zkeen.dat"
            ln -sf "$geo_dir/geosite_zkeen.dat" "$geo_dir/zkeen.dat"
        elif [ "$datfile" = "zkeen.dat" ]; then
            rm -f "$geo_dir/geosite_zkeen.dat"
            ln -sf "$geo_dir/zkeen.dat" "$geo_dir/geosite_zkeen.dat"
        fi
    fi
}