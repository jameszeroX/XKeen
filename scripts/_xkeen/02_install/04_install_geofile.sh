geofiles_update_state() {
    geofile_update="true"
    [ ! -f "$xkeen_config" ] && return 0
    local json_clean
    json_clean=$(strip_json_comments "$xkeen_config")
    local val
    val=$(printf '%s' "$json_clean" | sed -n 's/.*"geofile_update": *\([a-zA-Z]*\).*/\1/p' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' 2>/dev/null)
    [ "$val" = "false" ] && geofile_update="false"
}

# Проверяет, что URL — стандартный GitHub Release asset-URL
# (.../releases/latest/download/FILE или .../releases/download/TAG/FILE).
# Нужна для process_geo_file(): она обслуживает не только фиксированные
# GitHub-источники (geosite/geoip), но и произвольные пользовательские
# URL из update_user_geofiles() (xkeen.json: .xkeen.xray.geodata[].url),
# для которых verify_github_sha256 неприменима.
_is_github_release_url() {
    case "$1" in
        https://github.com/*/releases/latest/download/*|https://github.com/*/releases/download/*/*)
            return 0 ;;
        *)
            return 1 ;;
    esac
}

# Проверяет, настроены ли у пользователя собственные geodata-записи
# (.xkeen.xray.geodata[] в xkeen.json). Нужна как отдельный гейт входа
# в блок -ug: update_user_geofiles() сама корректно обрабатывает
# geodata, но до неё поток управления не доходит, если ни один из
# стандартных флагов обновления не выставлен.
has_user_geodata() {
    # shellcheck disable=SC2034 # используется в scripts/xkeen, блок -ug
    has_user_geodata="false"
    [ -f "$xkeen_config" ] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    if strip_json_comments "$xkeen_config" | jq -e '(.xkeen.xray.geodata // []) | length > 0' >/dev/null 2>&1; then
        # shellcheck disable=SC2034 # используется в scripts/xkeen, блок -ug
        has_user_geodata="true"
    fi
}

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
        printf "  ${yellow}Инфо${reset}: Без точного ожидаемого размера сравнение невозможно — загрузка пропущена, чтобы не подменить рабочий файл обрезанным\n"
        if [ -f "$geo_dir/$filename" ] || [ -L "$geo_dir/$filename" ]; then
            printf "  ${green}Оставляем старый файл${reset} %s\n\n" "$display_name"
        else
            printf "  ${red}Ошибка${reset}: старый файл %s отсутствует, а загрузка без проверки размера пропущена\n\n" "$display_name"
        fi
        return 1
    fi

    local tmp_file="${geo_dir}/${filename}.tmp.$$"

    # verify_github_sha256 запускаем только для стандартных GitHub Release
    # URL: process_geo_file() вызывается и для произвольных пользовательских
    # geofile-источников (update_user_geofiles()), для которых SHA-256 из
    # GitHub API недоступна
    if _download_and_validate_loop "$url" "$tmp_file" "$expected_size" "" "$display_name" && { ! _is_github_release_url "$url" || verify_github_sha256 "$tmp_file" "$url"; }; then
        mv -f "$tmp_file" "$geo_dir/$filename"
    else
        if [ -f "$tmp_file" ]; then
            rm -f "$tmp_file"
            _last_error="sha256_mismatch"
        fi
        # Обработка ошибок, если все попытки провалились
        case "$_last_error" in
            html_stub)
                printf "  ${red}Ошибка${reset}: получена HTML-страница вместо dat-файла\n"
                ;;
            size|size_mismatch)
                printf "  ${red}Ошибка${reset}: Размер загруженного файла не соответствует ожидаемому\n"
                ;;
            sha256_mismatch)
                printf "  ${red}Ошибка${reset}: Контрольная сумма SHA-256 файла %s не подтверждена\n" "$display_name"
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
    [ "$geofile_update" = "true" ] || return 0
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

    # Симлинки zkeen, если целевой файл присутствует (успешная загрузка либо уже был на диске)
    if [ -n "$zkeen_datfile" ] && [ -f "$geo_dir/$zkeen_datfile" ]; then
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
    [ "$geofile_update" = "true" ] || return 0
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

    # Симлинки zkeenip, если целевой файл присутствует (успешная загрузка либо уже был на диске)
    if [ -n "$zkeenip_datfile" ] && [ -f "$geo_dir/$zkeenip_datfile" ]; then
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
    [ "$geofile_update" = "true" ] || return 0
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
    strip_json_comments "$xkeen_config" | jq -c '.xkeen.xray.geodata[]?' > "$tmp_list" 2>/dev/null

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