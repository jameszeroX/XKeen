# Функция проверки доступности интернета
test_connection() {
    nslookup "$conn_URL" >/dev/null 2>&1 && return 0
    curl -Is --connect-timeout 1 "$conn_URL" >/dev/null && return 0
    ping -c 1 -W 1 "$conn_IP1" >/dev/null 2>&1 && return 0
    ping -c 1 -W 1 "$conn_IP2" >/dev/null 2>&1 && return 0

    printf "  ${red}Отсутствует${reset} интернет-соединение\n"
    exit 1
}

# Функция загрузки
download_with_check() {
    url="$1"
    output_file="$2"
    min_size="${3:-50000}"

    eval curl $curl_extra --connect-timeout 10 $curl_timeout -s -L "$url" -o "$output_file" 2>/dev/null

    if [ -f "$output_file" ]; then
        size=$(wc -c < "$output_file" 2>/dev/null || echo 0)
        if [ "$size" -gt "$min_size" ]; then
            return 0
        fi
    fi

    rm -f "$output_file" 2>/dev/null
    return 1
}

# Функция проверки доступности Entware
test_entware() {
    printf "  ${yellow}Проверка доступности${reset} репозитория Entware. Подождите, пожалуйста...\n"
    repo_url=$(awk '/^src/ {print $3; exit}' /opt/etc/opkg.conf 2>/dev/null)

    if [ -z "$repo_url" ]; then
        printf "  ${red}Не удалось${reset} определить используемый репозиторий Entware\n"
        exit 1
    fi

    repo_url="$repo_url/Packages.gz"
    tmp_file="/tmp/pkg_check_$$"

    if download_with_check "$repo_url" "$tmp_file"; then
        printf "  Репозиторий Entware ${green}доступен${reset}. Продолжаем...\n"

        opkg update >/dev/null 2>&1
        info_packages
        install_packages
        rm -f "$tmp_file" 2>/dev/null
        return 0
    else
        printf "  Репозиторий Entware ${red}недоступен${reset}\n"
        printf "  Укажите рабочее зеркало репозитория в файле ${yellow}/opt/etc/opkg.conf${reset}\n"
        exit 1
    fi
}

# Функция проверки доступности GitHub
test_github() {
    if [ "$use_direct" = "true" ] || [ -n "$gh_proxy" ]; then
        return 0
    fi
    use_direct="false"
    gh_proxy=""

    printf "  ${yellow}Проверка доступности${reset} GitHub. Подождите, пожалуйста...\n"

    _tmp1="/tmp/.xkeen_test_1.$$"
    _tmp2="/tmp/.xkeen_test_2.$$"

    _cleanup() {
        rm -f "$_tmp1" "$_tmp2" 2>/dev/null
    }

    _check_pair_download() {
        _prefix="$1"
        download_with_check "${_prefix}${xkeen_tar_url}" "$_tmp1" &&
        download_with_check "${_prefix}${xkeen_dev_url}" "$_tmp2"
    }

    # Загрузка через Proxy 1
    if _check_pair_download "${gh_proxy1}/"; then
        gh_proxy="$gh_proxy1"
        printf "  GitHub ${green}доступен через прокси${reset}. Продолжаем...\n"
        return 0
    fi

    # Загрузка через Proxy 2
    if _check_pair_download "${gh_proxy2}/"; then
        gh_proxy="$gh_proxy2"
        printf "  GitHub ${green}доступен через прокси${reset}. Продолжаем...\n"
        return 0
    fi

    # Прямая загрузка
    if _check_pair_download ""; then
        use_direct="true"
        printf "  GitHub ${green}доступен${reset}. Продолжаем...\n"
        return 0
    fi

    _cleanup
    printf "  ${red}Ошибка${reset}: GitHub недоступен\n"
    exit 1
}