# Валидаторы для fetch_with_mirrors: проверяют размер + базовый синтаксис
# содержимого (catch HTML-stub и мусор от proxy-error-page).
_validate_geoipset_v4() {
    _validate_default "$1" "$2" || return 1
    if ! grep -q "^[0-9]" "$1"; then
        _last_error="content_v4"
        return 1
    fi
    return 0
}

_validate_geoipset_v6() {
    _validate_default "$1" "$2" || return 1
    if ! grep -q "^[0-9a-fA-F]" "$1"; then
        _last_error="content_v6"
        return 1
    fi
    return 0
}

# Функция для установки и обновления GeoIPSET
install_geoipset_lst() {
    local url="$1"
    local dest_file="$2"
    local display_name="$3"
    local ip_type="$4"

    local _validator_name="_validate_geoipset_v4"
    if [ "$ip_type" != "ipv4" ]; then
        _validator_name="_validate_geoipset_v6"
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

    local tmp_file="${dest_file}.tmp.$$"

    # geoipv4_url/geoipv6_url всегда указывают на GitHub Release — проверка
    # безусловна (в отличие от process_geo_file(), которая обслуживает ещё и
    # произвольные пользовательские URL)
    if _download_and_validate_loop "$url" "$tmp_file" "$expected_size" "$_validator_name" "$display_name" && verify_github_sha256 "$tmp_file" "$url"; then
        mv -f "$tmp_file" "$dest_file"
    else
        if [ -f "$tmp_file" ]; then
            rm -f "$tmp_file"
            _last_error="sha256_mismatch"
        fi
        # Обработка ошибок, если все попытки провалились
        case "$_last_error" in
            html_stub)
                printf "  ${red}Ошибка${reset}: получена HTML-страница вместо списка IP\n"
                ;;
            content_v4)
                printf "  ${red}Ошибка${reset}: %s не содержит корректных IPv4-адресов\n" "$display_name"
                ;;
            content_v6)
                printf "  ${red}Ошибка${reset}: %s не содержит корректных IPv6-адресов\n" "$display_name"
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

        if [ "$action" != "init" ] && { [ -f "$dest_file" ] || [ -L "$dest_file" ]; }; then
            printf "  ${yellow}Инфо${reset}: Невозможно обновить %s. ${green}Оставляем старый файл${reset}\n\n" "$display_name"
        else
            printf "  ${yellow}Инфо${reset}: Невозможно загрузить %s\n\n" "$display_name"
        fi
        return 1
    fi

    [ "$action" = "init" ] && msg_geoipset="установлен" || msg_geoipset="обновлён"
    printf "  %s ${green}успешно $msg_geoipset${reset}\n\n" "$display_name"
    return 0
}

load_geoipset() {
    local set="$1"
    local file="$2"
    local family="$3"
    local tmp="${set}_tmp"
    local addr_regex

    # Тот же паттерн, что и в load_user_ipset_family (04_register_init.sh)
    if [ "$family" = "inet6" ]; then
        addr_regex='([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}(/[0-9]{1,3})?'
    else
        addr_regex='([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?'
    fi

    # Сериализация: cron `xkeen -ug`, ручной `xkeen -i/-gips` и new_features()
    # (-uk_post_update/-k_post_install) сходятся здесь на общем tmp-наборе
    # "${set}_tmp" — без лока параллельный create/flush/restore/swap/destroy
    # молча теряет записи geo_exclude/geo_exclude6 у обоих участников.
    # Тот же mkdir+pid-lock паттерн, что у _acquire_nf_lock в
    # 04_register_init.sh: kill -0 снимает лок мёртвого держателя, короткое
    # ограниченное ожидание уместно — restore идёт по уже скачанному
    # локальному файлу, в отличие от многоминутной загрузки install/upgrade.
    local _gi_rundir="" _gi_lockdir="" _gi_lock_owned="" _gi_try=0 _gi_lock_pid
    _gi_rundir=$(_xkeen_secure_rundir)
    if [ -n "$_gi_rundir" ]; then
        _gi_lockdir="$_gi_rundir/geoipset.lock.d"
        while [ "$_gi_try" -lt 50 ]; do
            if mkdir "$_gi_lockdir" 2>/dev/null; then
                _gi_lock_owned=1
                printf '%s' "$$" > "$_gi_lockdir/pid"
                break
            fi
            _gi_lock_pid=$(cat "$_gi_lockdir/pid" 2>/dev/null)
            if [ -n "$_gi_lock_pid" ] && ! kill -0 "$_gi_lock_pid" 2>/dev/null; then
                rm -rf "$_gi_lockdir" 2>/dev/null
                continue
            fi
            _gi_try=$((_gi_try + 1))
            usleep 100000 2>/dev/null || sleep 1
        done
        if [ -z "$_gi_lock_owned" ]; then
            # Держатель лока жив и всё ещё внутри критической секции ~5с
            # спустя (kill -0 проходил на каждой попытке выше — иначе лок
            # был бы снят как stale и цикл продолжился бы). Не отбираем
            # лок силой: это воссоздаёт ровно ту гонку (два живых процесса
            # одновременно работают над одним "${set}_tmp"), которую лок
            # должен закрывать. Пропускаем это обновление, оставляя
            # текущий "$set" нетронутым.
            printf "GeoIPSET: не удалось получить лок для '%s' — другой процесс ещё выполняет загрузку, обновление пропущено\n" "$set" >&2
            return 1
        fi
        trap 'rm -rf "$_gi_lockdir" 2>/dev/null; exit 1' INT TERM
        trap 'rm -rf "$_gi_lockdir" 2>/dev/null' EXIT
    fi

    # Заполняем tmp; основной набор подменяется только после успешного restore
    ipset create "$set" hash:net family "$family" -exist
    ipset create "$tmp" hash:net family "$family" -exist
    ipset flush "$tmp"

    if [ -f "$file" ] && sed -e 's/\r$//' -e 's/#.*//' -e '/^[[:space:]]*$/d' "$file" |
       grep -Eo "$addr_regex" |
       awk -v s="$tmp" '{print "add "s" "$1}' | ipset restore -exist; then
        ipset swap "$set" "$tmp"
    fi
    ipset destroy "$tmp"

    if [ -n "$_gi_lock_owned" ]; then
        trap - EXIT
        rm -rf "$_gi_lockdir" 2>/dev/null
    fi
}

install_geoipset() {
    local action="$1"

    if [ "$action" = "init" ]; then
        # Без TTY (cron, ssh -T) read получает EOF, default-case крутит while true
        # бесконечно: процесс висит в R-state с CPU-spin. Дефолтим выбор на "1"
        # (установить), потому что xkeen -gips из cron это типичный
        # non-interactive caller, где пользователь явно ожидает установку.
        if [ ! -t 0 ]; then
            printf "  Не интерактивный режим (нет TTY): автоматическая установка GeoIPSET\n"
            bypass_cron_geoipset=false
        else
            while true; do
                printf "\n  Желаете исключить российские IP-адреса из проксирования?\n\n"
                printf "     1. Загрузить и установить в исключения IP-подсети России (${yellow}GeoIPSET${reset})\n"
                printf "     0. Пропустить\n\n"
                printf "  Ваш выбор: "
                read -r choice

                case "$choice" in
                    0)
                        printf "  Выполнен пропуск установки списков GeoIPSET\n\n"

                        if [ ! -f "$ru_exclude_ipv4" ] && [ ! -f "$ru_exclude_ipv6" ]; then
                            bypass_cron_geoipset=true
                        fi
                        return 0
                        ;;
                    1)
                        mkdir -p "$ipset_cfg" || { echo "Ошибка: Не удалось создать директорию $ipset_cfg"; exit 1; }
                        bypass_cron_geoipset=false
                        break
                        ;;
                    *)
                        printf "  Неверный ввод. Пожалуйста, введите 1 или 0.\n"
                        ;;
                esac
            done
        fi
    fi

    if [ -d "$ipset_cfg" ]; then
        local do_v4=0 do_v6=0
        if ip -4 addr show 2>/dev/null | grep -q "inet " && command -v iptables >/dev/null 2>&1; then
            if [ "$action" = "init" ] || [ -f "$ru_exclude_ipv4" ]; then
                do_v4=1
            fi
        fi
        if check_ipv6_active && command -v ip6tables >/dev/null 2>&1; then
            if [ "$action" = "init" ] || [ -f "$ru_exclude_ipv6" ]; then
                do_v6=1
            fi
        fi
    
        # Последовательная загрузка списков вместо параллельной для совместимости с прогресс-баром
        [ "$do_v4" = "1" ] && install_geoipset_lst "$geoipv4_url" "$ru_exclude_ipv4" "IPv4 (IPSet)" "ipv4"
        [ "$do_v6" = "1" ] && install_geoipset_lst "$geoipv6_url" "$ru_exclude_ipv6" "IPv6 (IPSet)" "ipv6"
        [ "$do_v4" = "1" ] && load_geoipset geo_exclude "$ru_exclude_ipv4" inet
        [ "$do_v6" = "1" ] && load_geoipset geo_exclude6 "$ru_exclude_ipv6" inet6
    
        if [ ! -f "$ru_override" ]; then
            cat << EOF > "$ru_override"

# Добавьте IP и подсети, которые нужно исключить из IPSET ru_exclude
EOF
        fi
    fi
}