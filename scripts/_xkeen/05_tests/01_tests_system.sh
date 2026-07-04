# Функция проверки бинарников Entware
check_binary_health() {
    local program="$1"
    shift

    "$program" "$@" >/dev/null 2>&1
    local rc=$?

    local error_message=""

    case "$rc" in
        126) error_message="${program} не исполняемый файл" ;;
        127) error_message="${program} или системная библиотека не найдены" ;;
        132) error_message="${program} завершился с Illegal instruction" ;;
        139) error_message="${program} завершился с Segmentation fault" ;;
        134|135) error_message="${program} аварийно завершился" ;;
        *) return 0 ;;
    esac

    echo -e "  ${red}Критическая ошибка${reset}: $error_message"
    echo -e "  Исправьте ошибку локально или ${green}переустановите Entware${reset}"
    exit 1
}

# Функция предварительной проверки исправности системы
check_health() {
    local curl_err
    local exit_code

    check_binary_health busybox --help
    for prog in curl opkg grep; do
        check_binary_health "$prog" --version
    done

    # Делаем быстрый HTTPS запрос
    curl_err=$(curl --connect-timeout 3 -IsS "https://$conn_URL" 2>&1 >/dev/null)
    exit_code=$?

    # Если успешно, сразу выходим из функции
    [ "$exit_code" -eq 0 ] && return 0

    # Проверка на сломанные SSL-сертификаты
    if [ "$exit_code" -eq 60 ] || [ "$exit_code" -eq 77 ] || echo "$curl_err" | grep -iqE '(certificate|ssl|ca-bundle)'; then
        printf "  ${red}Критическая ошибка${reset}: Нарушена целостность SSL-сертификатов в Entware!\n"
        printf "  Интернет доступен, но curl не может проверить безопасность HTTPS-соединения\n"
        [ -n "$curl_err" ] && printf "  ${yellow}%s${reset}\n" "$curl_err"
        printf "  Исправьте ошибку локально или ${green}переустановите Entware${reset}\n\n"
        exit 1
    fi

    return 0
}

# Функция проверки доступности интернета
test_connection() {
    nslookup "$conn_URL" >/dev/null 2>&1 && return 0
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

    curl --connect-timeout 5 -m 15 -y 1000 -Y 5 -s -L "$url" -o "$output_file" 2>/dev/null

    if [ -f "$output_file" ]; then
        size=$(wc -c < "$output_file" 2>/dev/null || echo 0)
        if [ "$size" -gt "$min_size" ]; then
            if head -c 100 "$output_file" 2>/dev/null | grep -iqE '^(<!doctype|<html|<head|<body|404|error|not found)'; then
                rm -f "$output_file" 2>/dev/null
                return 1
            fi
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

# Функция определения пользовательского прокси для GitHub
get_user_proxy() {
    gh_proxy_user=""
    [ ! -f "$xkeen_config" ] && return 1

    if command -v jq >/dev/null 2>&1; then
        gh_proxy_user=$(jq -r '.xkeen.gh_proxy // empty' "$xkeen_config" 2>/dev/null)
    fi

    if [ -z "$gh_proxy_user" ]; then
        gh_proxy_user=$(sed -n 's/.*"gh_proxy": *"\([^"]*\)".*/\1/p' "$xkeen_config" | xargs 2>/dev/null)
    fi

    [ "$gh_proxy_user" = "null" ] && gh_proxy_user=""
}

# Функция проверки доступности GitHub.
# Тонкая обёртка над probe_with_mirrors: идентичная философия (пара URL
# через одну цепочку префиксов, exclusive gh_proxy_user, exit 1 на
# полную недоступность), но один engine fallback в helper'е вместо
# дублирования логики direct/proxy1/proxy2 здесь.
test_github() {
    [ -n "$_gh_probed" ] && return 0

    get_user_proxy

    printf "  ${yellow}Проверка доступности${reset} GitHub. Подождите, пожалуйста...\n"

    # Pair probe: github.com (releases) + raw.githubusercontent.com
    # (для dev-обновления). Разные CDN, разный uptime, проверяем оба.
    if probe_with_mirrors "$xkeen_tar_url" && probe_with_mirrors "$xkeen_dev_url"; then
        _gh_probed=1
        if [ -n "$gh_proxy_user" ]; then
            printf "  GitHub ${green}доступен через ваш прокси${reset}: ${yellow}$gh_proxy_user${reset}. Продолжаем...\n"
        elif [ -r /tmp/.xkeen_mirror_cache ] && grep -q "__direct__" /tmp/.xkeen_mirror_cache 2>/dev/null; then
            printf "  GitHub ${green}доступен${reset}. Продолжаем...\n"
        else
            printf "  GitHub ${green}доступен через прокси${reset}. Продолжаем...\n"
        fi
        return 0
    fi

    if [ -n "$gh_proxy_user" ]; then
        printf "  ${red}Ошибка${reset}: Указанный вами прокси $gh_proxy_user недоступен\n"
    else
        printf "  ${red}Ошибка${reset}: GitHub недоступен\n"
    fi
    exit 1
}