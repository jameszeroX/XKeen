geofiles_update_state() {
    geofile_update="true"
    [ ! -f "$xkeen_config" ] && return 0
    local val
    if ! command -v jq >/dev/null 2>&1; then
        printf '  Предупреждение: jq не найден, geofile_update использует значение по умолчанию\n' >&2
        return 1
    fi
    val=$(strip_json_comments "$xkeen_config" | jq -er '
        if type != "object" then error("root is not an object")
        elif (.xkeen | type) != "object" then "default"
        elif (.xkeen.xray | type) != "object" then "default"
        elif (.xkeen.xray | has("geofile_update") | not) then "default"
        elif (.xkeen.xray.geofile_update | type) == "boolean" then
            if .xkeen.xray.geofile_update then "true" else "false" end
        elif .xkeen.xray.geofile_update == null then "default"
        else error("geofile_update must be a boolean or null") end
    ' 2>/dev/null) || {
        printf '  Предупреждение: некорректный geofile_update; используется значение по умолчанию\n' >&2
        return 1
    }
    case "$val" in
        false) geofile_update="false" ;;
        true|default) ;;
        *) return 1 ;;
    esac
}

# Создавать ли симлинки zkeen.dat <-> geosite_zkeen.dat и
# zkeenip.dat <-> geoip_zkeenip.dat: ключ .xkeen.xray.geofile_symlinks
# в xkeen.json (boolean, на одном уровне с geofile_update и geodata;
# нет ключа / null / нет .xkeen.xray / нет файла / нет jq /
# некорректное значение — true, как и раньше).
# false отключает только СОЗДАНИЕ симлинков: уже существующие не удаляются.
#
# Читается здесь, а не в geofiles_update_state(): та вызывается лишь из -ug, а
# install_geosite/install_geoip работают ещё и из -i и -g, где geofile_update
# выставляется напрямую. Результат запоминается на время процесса, чтобы не
# разбирать файл и не выводить предупреждение дважды (GeoSite и GeoIP).
# Возврат: 0 — создавать симлинки, 1 — не создавать.
_geofile_symlinks_state=""
geofile_symlinks_enabled() {
    local val
    if [ -z "$_geofile_symlinks_state" ]; then
        _geofile_symlinks_state="true"
        if [ -f "$xkeen_config" ] && command -v jq >/dev/null 2>&1; then
            val=$(strip_json_comments "$xkeen_config" | jq -er '
                if type != "object" then error("root is not an object")
                elif (.xkeen | type) != "object" then "default"
                elif (.xkeen.xray | type) != "object" then "default"
                elif (.xkeen.xray | has("geofile_symlinks") | not) then "default"
                elif (.xkeen.xray.geofile_symlinks | type) == "boolean" then
                    if .xkeen.xray.geofile_symlinks then "true" else "false" end
                elif .xkeen.xray.geofile_symlinks == null then "default"
                else error("geofile_symlinks must be a boolean or null") end
            ' 2>/dev/null) || {
                printf '  Предупреждение: некорректный geofile_symlinks; используется значение по умолчанию (true)\n' >&2
                val="default"
            }
            [ "$val" = "false" ] && _geofile_symlinks_state="false"
        fi
    fi
    [ "$_geofile_symlinks_state" = "true" ]
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
        if ! mv -f "$tmp_file" "$geo_dir/$filename"; then
            rm -f "$tmp_file"
            printf "  ${red}Ошибка${reset}: не удалось установить файл %s\n" "$display_name"
            if [ -f "$geo_dir/$filename" ] || [ -L "$geo_dir/$filename" ]; then
                printf "  ${green}Оставляем старый файл${reset} %s\n\n" "$display_name"
            fi
            return 1
        fi
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
    local geofile_status=0

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
        process_geo_file "$refilter_url" "geosite_refilter.dat" "GeoSite Re:filter" "$update_refilter_geosite" || geofile_status=1
    fi

    if [ "$install_v2fly_geosite" = "true" ] || [ "$update_v2fly_geosite" = "true" ]; then
        process_geo_file "$v2fly_url" "geosite_v2fly.dat" "GeoSite V2Fly" "$update_v2fly_geosite" || geofile_status=1
    fi

    if [ -n "$zkeen_datfile" ]; then
        process_geo_file "$zkeen_url" "$zkeen_datfile" "GeoSite ZKeen" "$update_zkeen_geosite" || geofile_status=1
    fi

    # Симлинки zkeen, если целевой файл присутствует (успешная загрузка либо уже был на диске)
    # и их создание не отключено (xkeen.xray.geofile_symlinks = false)
    if [ -n "$zkeen_datfile" ] && [ -f "$geo_dir/$zkeen_datfile" ] && geofile_symlinks_enabled; then
        if [ "$zkeen_datfile" = "geosite_zkeen.dat" ]; then
            local alias_tmp="$geo_dir/zkeen.dat.tmp.$$"
            if ! ln -s "$geo_dir/geosite_zkeen.dat" "$alias_tmp" || ! mv -f "$alias_tmp" "$geo_dir/zkeen.dat"; then
                rm -f "$alias_tmp"
                geofile_status=1
            fi
        else
            local alias_tmp="$geo_dir/geosite_zkeen.dat.tmp.$$"
            if ! ln -s "$geo_dir/zkeen.dat" "$alias_tmp" || ! mv -f "$alias_tmp" "$geo_dir/geosite_zkeen.dat"; then
                rm -f "$alias_tmp"
                geofile_status=1
            fi
        fi
    fi
    return "$geofile_status"
}

# Функция для установки и обновления GeoIP
install_geoip() {
    [ "$geofile_update" = "true" ] || return 0
    mkdir -p "$geo_dir" || { echo "Ошибка: Не удалось создать директорию $geo_dir"; exit 1; }
    local geofile_status=0

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
        process_geo_file "$refilterip_url" "geoip_refilter.dat" "GeoIP Re:filter" "$update_refilter_geoip" || geofile_status=1
    fi

    if [ "$install_v2fly_geoip" = "true" ] || [ "$update_v2fly_geoip" = "true" ]; then
        process_geo_file "$v2flyip_url" "geoip_v2fly.dat" "GeoIP V2Fly" "$update_v2fly_geoip" || geofile_status=1
    fi

    if [ -n "$zkeenip_datfile" ]; then
        process_geo_file "$zkeenip_url" "$zkeenip_datfile" "GeoIP ZKeenIP" "$update_zkeenip_geoip" || geofile_status=1
    fi

    # Симлинки zkeenip, если целевой файл присутствует (успешная загрузка либо уже был на диске)
    # и их создание не отключено (xkeen.xray.geofile_symlinks = false)
    if [ -n "$zkeenip_datfile" ] && [ -f "$geo_dir/$zkeenip_datfile" ] && geofile_symlinks_enabled; then
        if [ "$zkeenip_datfile" = "geoip_zkeenip.dat" ]; then
            local alias_tmp="$geo_dir/zkeenip.dat.tmp.$$"
            if ! ln -s "$geo_dir/geoip_zkeenip.dat" "$alias_tmp" || ! mv -f "$alias_tmp" "$geo_dir/zkeenip.dat"; then
                rm -f "$alias_tmp"
                geofile_status=1
            fi
        else
            local alias_tmp="$geo_dir/geoip_zkeenip.dat.tmp.$$"
            if ! ln -s "$geo_dir/zkeenip.dat" "$alias_tmp" || ! mv -f "$alias_tmp" "$geo_dir/geoip_zkeenip.dat"; then
                rm -f "$alias_tmp"
                geofile_status=1
            fi
        fi
    fi
    return "$geofile_status"
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

    if ! strip_json_comments "$xkeen_config" | jq -e '
        if ((.xkeen? | type) != "object") then true
        elif ((.xkeen.xray? | type) != "object") then true
        elif (.xkeen.xray | has("geodata") | not) then true
        else
            (.xkeen.xray.geodata | type == "array" and all(.[];
                type == "object"
                and (.file | type == "string" and length > 0 and . != "." and . != ".."
                     and (contains("/") | not) and (contains("\\") | not)
                     and (explode | all(.[]; . >= 32 and . != 127)))
                and ((.url | type == "string") and (.url as $url
                    | (if ($url | startswith("https://")) then $url[8:]
                       elif ($url | startswith("http://")) then $url[7:]
                       else "" end) as $url_tail
                    | ($url_tail | split("/")[0] | split("?")[0] | split("#")[0]) as $authority
                    | ($url_tail | length > 0)
                      and ($authority | length > 0)
                      and ($url_tail | explode | all(.[]; . > 32 and . != 127))
                ))
            ))
        end
    ' >/dev/null 2>&1; then
        printf "  ${red}Ошибка${reset}: Некорректная структура пользовательских geodata в ${yellow}xkeen.json${reset}\n\n"
        return 1
    fi

    local tmp_list="${geo_dir}/.geofile_list.$$"
    if ! strip_json_comments "$xkeen_config" | jq -c '.xkeen.xray.geodata[]?' > "$tmp_list" 2>/dev/null; then
        rm -f "$tmp_list"
        return 1
    fi

    if [ ! -s "$tmp_list" ]; then
        rm -f "$tmp_list" || return 1
        return 0
    fi

    local entry file url update_flag
    local failed_files=''
    local invalid_entry=false

    while IFS= read -r entry; do
        file=$(printf '%s' "$entry" | jq -r '.file // empty')
        url=$(printf '%s' "$entry" | jq -r '.url // empty')

        if [ -z "$file" ] || [ -z "$url" ]; then
            printf "  ${red}Ошибка${reset}: Некорректная запись в разделе ${light_blue}geofile${reset} файла ${yellow}xkeen.json${reset}\n\n"
            invalid_entry=true
            break
        fi

        if [ -f "$geo_dir/$file" ] || [ -L "$geo_dir/$file" ]; then
            update_flag="true"
        else
            update_flag="false"
        fi

        if ! process_geo_file "$url" "$file" "$file" "$update_flag"; then
            failed_files="${failed_files}${failed_files:+, }${file}"
        fi
    done < "$tmp_list"

    if ! rm -f "$tmp_list"; then
        printf "  ${red}Ошибка${reset}: не удалось удалить временный список пользовательских geofile\n\n"
        return 1
    fi
    [ "$invalid_entry" = false ] || return 1
    if [ -n "$failed_files" ]; then
        printf "  ${red}Ошибка${reset}: не удалось обновить пользовательские geofile: %s\n\n" "$failed_files"
        return 1
    fi
    return 0
}
