# Функция проверки доступности интернета
test_connection() {
    result=1

    if ! ping -c 2 -W 5 "$conn_IP1" >/dev/null 2>&1 && \
       ! ping -c 2 -W 5 "$conn_IP2" >/dev/null 2>&1; then
        result=0
    fi

    if [ "$result" -eq 0 ]; then
        printf "  ${red}Отсутствует${reset} интернет-соединение\n"
        exit 1
    fi
}

# Функция загрузки
download_with_check() {
    url="$1"
    output_file="$2"
    min_size="${3:-300000}"

    curl --connect-timeout 10 $curl_timeout -s -L "$url" -o "$output_file" 2>/dev/null

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
        opkg upgrade >/dev/null 2>&1
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

    _gh_head_check() {
        _url="$1"
        _status=$(curl --connect-timeout 10 $curl_timeout -s -L -I -o /dev/null -w "%{http_code}" "$_url" 2>/dev/null)
        if [ "$_status" = "405" ]; then
            _status=$(curl --connect-timeout 10 $curl_timeout -s -L -r 0-0 -o /dev/null -w "%{http_code}" "$_url" 2>/dev/null)
        fi
        case "$_status" in
            2[0-9][0-9]) return 0 ;;
            *) return 1 ;;
        esac
    }

    if _gh_head_check "$zkeenip_url"; then
        use_direct="true"
        printf "  GitHub ${green}доступен${reset}. Продолжаем...\n"
        return 0
    fi

    if _gh_head_check "${gh_proxy1}/${zkeenip_url}"; then
        gh_proxy="$gh_proxy1"
        printf "  GitHub ${green}доступен через прокси${reset}. Продолжаем...\n"
        return 0
    fi

    if _gh_head_check "${gh_proxy2}/${zkeenip_url}"; then
        gh_proxy="$gh_proxy2"
        printf "  GitHub ${green}доступен через прокси${reset}. Продолжаем...\n"
        return 0
    fi

    printf "  ${red}Ошибка${reset}: GitHub недоступен\n"
    exit 1
}