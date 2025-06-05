# Функция для установки и обновления GeoIP
install_geoip() {
    mkdir -p "$geo_dir" || { echo "Ошибка: Не удалось создать директорию $geo_dir"; exit 1; }

    if [ -f "$geo_dir/geoip_antifilter.dat" ]; then
        update_antifilter_geoip_msg=true
    fi
    if [ -f "$geo_dir/geoip_v2fly.dat" ]; then
        update_v2fly_geoip_msg=true
    fi
    if [ -f "$geo_dir/geoip_zkeenip.dat" ]; then
        update_zkeenip_geoip_msg=true
    fi

    # Установка GeoIP AntiFilter
    if [ "$install_antifilter_geoip" = true ]; then
        antifilterip_dat=$(mktemp)
        if curl -L -o "$antifilterip_dat" "https://github.com/Skrill0/AntiFilter-IP/releases/latest/download/geoip.dat" > /dev/null 2>&1; then
            mv "$antifilterip_dat" "$geo_dir/geoip_antifilter.dat"
            if [ $? -eq 0 ] && [ -s "$geo_dir/geoip_antifilter.dat" ]; then
                if [ "$update_antifilter_geoip_msg" = true ]; then
                    echo -e "  GeoIP AntiFilter ${green}успешно обновлен${reset}"
                else
                    echo -e "  GeoIP AntiFilter ${green}успешно установлен${reset}"
                fi
            else
                echo -e "  ${red}Неизвестная ошибка${reset} при установке GeoIP AntiFilter"
            fi
        else
            rm -f "$antifilterip_dat"
            echo "  ${red}Ошибка${reset} при загрузке GeoIP AntiFilter. Проверьте соединение с интернетом или повторите позже"
        fi
    fi

    # Установка GeoIP V2Fly
    if [ "$install_v2fly_geoip" = true ]; then
        v2flyip_dat=$(mktemp)
        if curl -L -o "$v2flyip_dat" "https://github.com/loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" > /dev/null 2>&1; then
            mv "$v2flyip_dat" "$geo_dir/geoip_v2fly.dat"
            if [ $? -eq 0 ] && [ -s "$geo_dir/geoip_v2fly.dat" ]; then
                if [ "$update_v2fly_geoip_msg" = true ]; then
                    echo -e "  GeoIP V2Fly ${green}успешно обновлен${reset}"
                else
                    echo -e "  GeoIP V2Fly ${green}успешно установлен${reset}"
                fi
            else
                echo -e "  ${red}Неизвестная ошибка${reset} при установке GeoIP V2Fly"
            fi
        else
            rm -f "$v2flyip_dat"
            echo "  ${red}Ошибка${reset} при загрузке GeoIP V2Fly. Проверьте соединение с интернетом или повторите позже"
        fi
    fi

    # Установка GeoIP ZkeenIP
    if [ "$install_zkeenip_geoip" = true ]; then
        zkeenip_dat=$(mktemp)
        if curl -L -o "$zkeenip_dat" "https://github.com/jameszeroX/zkeen-ip/releases/latest/download/zkeenip.dat" > /dev/null 2>&1; then
            rm -f "$geo_dir/zkeenip.dat" "$geo_dir/geoip_zkeenip.dat"
            mv "$zkeenip_dat" "$geo_dir/geoip_zkeenip.dat"
            ln -s "$geo_dir/geoip_zkeenip.dat" "$geo_dir/zkeenip.dat"
            if [ $? -eq 0 ] && [ -s "$geo_dir/geoip_zkeenip.dat" ]; then
                if [ "$update_zkeenip_geoip_msg" = true ]; then
                    echo -e "  GeoIP ZkeenIP ${green}успешно обновлен${reset}"
                else
                    echo -e "  GeoIP ZkeenIP ${green}успешно установлен${reset}"
                fi
            else
                echo -e "  ${red}Неизвестная ошибка${reset} при установке GeoIP ZkeenIP"
            fi
        else
            rm -f "$zkeenip_dat"
            echo "  ${red}Ошибка${reset} при загрузке GeoIP ZkeenIP. Проверьте соединение с интернетом или повторите позже"
        fi
    fi

    # Обновление GeoIP AntiFilter, если установлены и требуется обновление
    if [ "$update_antifilter_geoip" = true ]; then
        antifilterip_dat=$(mktemp)
        if curl -L -o "$antifilterip_dat" "https://github.com/Skrill0/AntiFilter-IP/releases/latest/download/geoip.dat" > /dev/null 2>&1; then
            mv "$antifilterip_dat" "$geo_dir/geoip_antifilter.dat"
            if [ $? -eq 0 ] && [ -s "$geo_dir/geoip_antifilter.dat" ]; then
                echo -e "  GeoIP AntiFilter ${green}успешно обновлен${reset}"
            else
                echo -e "  ${red}Неизвестная ошибка${reset} при обновлении GeoIP AntiFilter"
            fi
        else
            rm -f "$antifilterip_dat"
            echo "  ${red}Ошибка${reset} при загрузке GeoIP AntiFilter. Проверьте соединение с интернетом или повторите позже"
        fi
    fi

    # Обновление GeoIP V2Fly, если установлены и требуется обновление
    if [ "$update_v2fly_geoip" = true ]; then
        v2flyip_dat=$(mktemp)
        if curl -L -o "$v2flyip_dat" "https://github.com/loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" > /dev/null 2>&1; then
            mv "$v2flyip_dat" "$geo_dir/geoip_v2fly.dat"
            if [ $? -eq 0 ] && [ -s "$geo_dir/geoip_v2fly.dat" ]; then
                echo -e "  GeoIP V2Fly ${green}успешно обновлен${reset}"
            else
                echo -e "  ${red}Неизвестная ошибка${reset} при обновлении GeoIP V2Fly"
            fi
        else
            rm -f "$v2flyip_dat"
            echo "  ${red}Ошибка${reset} при загрузке GeoIP V2Fly. Проверьте соединение с интернетом или повторите позже"
        fi
    fi

    # Обновление GeoIP ZkeenIP, если установлены и требуется обновление
    if [ "$update_zkeenip_geoip" = true ]; then
        zkeenip_dat=$(mktemp)
        if curl -L -o "$zkeenip_dat" "https://github.com/jameszeroX/zkeen-ip/releases/latest/download/zkeenip.dat" > /dev/null 2>&1; then
            rm -f "$geo_dir/zkeenip.dat" "$geo_dir/geoip_zkeenip.dat"
            mv "$zkeenip_dat" "$geo_dir/geoip_zkeenip.dat"
            ln -s "$geo_dir/geoip_zkeenip.dat" "$geo_dir/zkeenip.dat"
            if [ $? -eq 0 ] && [ -s "$geo_dir/geoip_zkeenip.dat" ]; then
                echo -e "  GeoIP ZkeenIP ${green}успешно обновлен${reset}"
            else
                echo -e "  ${red}Неизвестная ошибка${reset} при обновлении GeoIP ZkeenIP"
            fi
        else
            rm -f "$zkeenip_dat"
            echo "  ${red}Ошибка${reset} при загрузке GeoIP ZkeenIP. Проверьте соединение с интернетом или повторите позже"
        fi
    fi
}
