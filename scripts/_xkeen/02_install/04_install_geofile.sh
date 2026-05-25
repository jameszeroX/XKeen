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

    local min_size=24576  # 24 KB

    # Если переменная retries_download не задана, используем одну попытку
    local max_attempts=1
    if [ -n "$retries_download" ] && [ "$retries_download" -gt 1 ] 2>/dev/null; then
        max_attempts=$retries_download
    fi

    local delay=${retry_delay_download:-2}

    local attempt=1
    local success=1

    while [ "$attempt" -le "$max_attempts" ]; do
        # Выводим инфо о попытках только если их больше одной
        if [ "$max_attempts" -gt 1 ]; then
            printf "  Загрузка %s (Попытка %d из %d)...\n" "$display_name" "$attempt" "$max_attempts"
        else
            printf "  Загрузка %s...\n" "$display_name"
        fi

        if fetch_with_mirrors "$url" "$geo_dir/$filename" "$min_size"; then
            success=0
            break
        fi

        # Если загрузка сорвалась и это НЕ последняя попытка — ждем и повторяем
        if [ "$attempt" -lt "$max_attempts" ]; then
            printf "  ${yellow}Предупреждение${reset}: Попытка %d не удалась. Повтор через %d сек...\n" "$attempt" "$delay"
            sleep "$delay"
        fi

        attempt=$((attempt + 1))
    done

    # Обработка ошибок, если все попытки провалились
    if [ "$success" -ne 0 ]; then
        case "$_last_error" in
            size)
                printf "  ${red}Ошибка${reset}: загруженный файл слишком мал (%s bytes) или повреждён\n  Невозможно обновить. Оставляем старый файл\n\n" "$_last_size"
                ;;
            html_stub)
                printf "  ${red}Ошибка${reset}: получена HTML-страница вместо dat-файла\n  Невозможно обновить. Оставляем старый файл\n\n"
                ;;
            *)
                if [ "$max_attempts" -gt 1 ]; then
                    printf "  ${red}Ошибка${reset}: не удалось загрузить %s после %d попыток\n\n" "$display_name" "$max_attempts"
                else
                    printf "  ${red}Ошибка${reset}: не удалось загрузить %s\n\n" "$display_name"
                fi
                ;;
        esac
        return 1
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

    local zkeen_datfile=""
    if [ "$install_zkeen_geosite" = "true" ] || [ "$update_zkeen_geosite" = "true" ]; then
        zkeen_datfile="geosite_zkeen.dat"
        if [ -L "$geo_dir/geosite_zkeen.dat" ]; then
            zkeen_datfile="zkeen.dat"
        elif [ -L "$geo_dir/zkeen.dat" ]; then
            zkeen_datfile="geosite_zkeen.dat"
        elif [ -f "$geo_dir/zkeen.dat" ] && ! [ -f "$geo_dir/geosite_zkeen.dat" ]; then
            zkeen_datfile="zkeen.dat"
        fi
    fi

    # Последовательная загрузка геофайлов вместо параллельной для совместимости с прогресс-баром
    if [ "$install_refilter_geosite" = "true" ] || [ "$update_refilter_geosite" = "true" ]; then
        process_geo_file "$refilter_url" "geosite_refilter.dat" \
            "GeoSite Re:filter" "$update_refilter_geosite"
    fi

    if [ "$install_v2fly_geosite" = "true" ] || [ "$update_v2fly_geosite" = "true" ]; then
        process_geo_file "$v2fly_url" "geosite_v2fly.dat" \
            "GeoSite V2Fly" "$update_v2fly_geosite"
    fi

    if [ -n "$zkeen_datfile" ]; then
        process_geo_file "$zkeen_url" "$zkeen_datfile" \
            "GeoSite ZKeen" "$update_zkeen_geosite"
    fi

    # Симлинки zkeen после успешной загрузки
    if [ -n "$zkeen_datfile" ]; then
        if [ "$zkeen_datfile" = "geosite_zkeen.dat" ]; then
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

    local zkeenip_datfile=""
    if [ "$install_zkeenip_geoip" = "true" ] || [ "$update_zkeenip_geoip" = "true" ]; then
        zkeenip_datfile="geoip_zkeenip.dat"
        if [ -L "$geo_dir/geoip_zkeenip.dat" ]; then
            zkeenip_datfile="zkeenip.dat"
        elif [ -L "$geo_dir/zkeenip.dat" ]; then
            zkeenip_datfile="geoip_zkeenip.dat"
        elif [ -f "$geo_dir/zkeenip.dat" ] && ! [ -f "$geo_dir/geoip_zkeenip.dat" ]; then
            zkeenip_datfile="zkeenip.dat"
        fi
    fi

    # Последовательная загрузка геофайлов вместо параллельной для совместимости с прогресс-баром
    if [ "$install_refilter_geoip" = "true" ] || [ "$update_refilter_geoip" = "true" ]; then
        process_geo_file "$refilterip_url" "geoip_refilter.dat" \
            "GeoIP Re:filter" "$update_refilter_geoip"
    fi

    if [ "$install_v2fly_geoip" = "true" ] || [ "$update_v2fly_geoip" = "true" ]; then
        process_geo_file "$v2flyip_url" "geoip_v2fly.dat" \
            "GeoIP V2Fly" "$update_v2fly_geoip"
    fi

    if [ -n "$zkeenip_datfile" ]; then
        process_geo_file "$zkeenip_url" "$zkeenip_datfile" \
            "GeoIP ZKeenIP" "$update_zkeenip_geoip"
    fi

    # Симлинки zkeenip после успешной загрузки
    if [ -n "$zkeenip_datfile" ]; then
        if [ "$zkeenip_datfile" = "geoip_zkeenip.dat" ]; then
            rm -f "$geo_dir/zkeenip.dat"
            ln -sf "$geo_dir/geoip_zkeenip.dat" "$geo_dir/zkeenip.dat"
        else
            rm -f "$geo_dir/geoip_zkeenip.dat"
            ln -sf "$geo_dir/zkeenip.dat" "$geo_dir/geoip_zkeenip.dat"
        fi
    fi
}