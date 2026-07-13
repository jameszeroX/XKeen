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

    # Получаем ожидаемый размер файла
    local expected_size=""
    printf "  Запрос информации о %s...\n" "$display_name"

    if expected_size=$(_get_expected_size "$url"); then
        printf "  Ожидаемый размер: ${yellow}%s байт${reset}\n" "$expected_size"
    else
        printf "  ${yellow}Предупреждение${reset}: Не удалось определить ожидаемый размер файла\n"
        expected_size=""
    fi

    local tmp_file="${geo_dir}/${filename}.tmp.$$"

    if _download_and_validate_loop "$url" "$tmp_file" "$expected_size" "" "$display_name"; then
        mv -f "$tmp_file" "$geo_dir/$filename"
    else
        # Обработка ошибок, если все попытки провалились
        case "$_last_error" in
            html_stub)
                printf "  ${red}Ошибка${reset}: получена HTML-страница вместо dat-файла\n"
                ;;
            size|size_mismatch)
                printf "  ${red}Ошибка${reset}: Размер загруженного файла не соответствует ожидаемому\n"
                ;;
            *)
                local max_attempts=${retries_download:-1}
                if [ "$max_attempts" -gt 1 ]; then
                    printf "  ${red}Ошибка${reset}: не удалось загрузить %s после %d попыток\n" "$display_name" "$max_attempts"
                else
                    printf "  ${red}Ошибка${reset}: не удалось загрузить %s\n" "$display_name"
                fi
                ;;
        esac

        if [ "$update_flag" = "true" ] && { [ -f "$geo_dir/$filename" ] || [ -L "$geo_dir/$filename" ]; }; then
            printf "  ${yellow}Инфо${reset}: Невозможно обновить %s. ${green}Оставляем старый файл${reset}\n\n" "$display_name"
        else
            printf "  ${yellow}Инфо${reset}: Невозможно загрузить %s\n\n" "$display_name"
        fi
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
        process_geo_file "$refilter_url" "geosite_refilter.dat" "GeoSite Re:filter" "$update_refilter_geosite"
    fi

    if [ "$install_v2fly_geosite" = "true" ] || [ "$update_v2fly_geosite" = "true" ]; then
        process_geo_file "$v2fly_url" "geosite_v2fly.dat" "GeoSite V2Fly" "$update_v2fly_geosite"
    fi

    if [ -n "$zkeen_datfile" ]; then
        process_geo_file "$zkeen_url" "$zkeen_datfile" "GeoSite ZKeen" "$update_zkeen_geosite"
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
        process_geo_file "$refilterip_url" "geoip_refilter.dat" "GeoIP Re:filter" "$update_refilter_geoip"
    fi

    if [ "$install_v2fly_geoip" = "true" ] || [ "$update_v2fly_geoip" = "true" ]; then
        process_geo_file "$v2flyip_url" "geoip_v2fly.dat" "GeoIP V2Fly" "$update_v2fly_geoip"
    fi

    if [ -n "$zkeenip_datfile" ]; then
        process_geo_file "$zkeenip_url" "$zkeenip_datfile" "GeoIP ZKeenIP" "$update_zkeenip_geoip"
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

# Функция для обновления пользовательских геофайлов
update_user_geofiles() {
    mkdir -p "$geo_dir" || { echo "Ошибка: Не удалось создать директорию $geo_dir"; exit 1; }

    [ -f "$xkeen_config" ] || return 0

    if ! command -v jq >/dev/null 2>&1; then
        printf "  ${red}Ошибка${reset}: jq не найден, пропуск обработки пользовательских геофайлов\n\n"
        return 1
    fi

    if ! strip_json_comments "$xkeen_config" | jq empty >/dev/null 2>&1; then
        printf "  ${red}Ошибка${reset}: Некорректный JSON в файле ${yellow}xkeen.json${reset}\n\n"
        return 1
    fi

    local tmp_list="${geo_dir}/.geofile_list.$$"
    strip_json_comments "$xkeen_config" | jq -c '.xkeen.geodata[]?' > "$tmp_list" 2>/dev/null

    if [ ! -s "$tmp_list" ]; then
        rm -f "$tmp_list"
        return 0
    fi

    local entry file url update_flag

    while IFS= read -r entry; do
        file=$(printf '%s' "$entry" | jq -r '.file // empty')
        url=$(printf '%s' "$entry" | jq -r '.url // empty')

        if [ -z "$file" ] || [ -z "$url" ]; then
            printf "  ${red}Ошибка${reset}: Некорректная запись в разделе ${light_blue}geofile${reset} файла ${yellow}xkeen.json${reset}\n\n"
            return 1
        fi

        if [ -f "$geo_dir/$file" ] || [ -L "$geo_dir/$file" ]; then
            update_flag="true"
        else
            update_flag="false"
        fi

        process_geo_file "$url" "$file" "$file" "$update_flag"
    done < "$tmp_list"

    rm -f "$tmp_list"
}