#!/bin/sh

green="\033[92m"
red="\033[91m"
yellow="\033[93m"
light_blue="\033[96m"
italic="\033[3m"
reset="\033[0m"

url_stable="https://github.com/jameszeroX/XKeen/releases/latest/download/xkeen.tar.gz"
url_beta="https://raw.githubusercontent.com/jameszeroX/XKeen/main/test/xkeen.tar.gz"
archive_name="xkeen.tar.gz"
xkeen_config="/opt/etc/xkeen/xkeen.json"

# Функция для вывода справки
show_help() {
echo
echo -e "  ${yellow}Использование${reset}: $0 [ОПЦИИ]"
echo
echo -e "  ${yellow}Опции${reset}"
echo -e "    -s, --stable	${italic}Установить стабильную версию${reset}"
echo -e "    -b, --beta		${italic}Установить бета-версию${reset}"
echo -e "    -l, --legacy ВЕРСИЯ	${italic}Установить предыдущую версию (например, 1.1.3.9)${reset}"
echo -e "    -h, --help		${italic}Показать эту справку${reset}"
echo
echo -e "  ${yellow}Примеры${reset}"
echo  "    $0 --stable"
echo  "    $0 --beta"
echo  "    $0 --legacy 1.1.3.9"
echo  "    $0 --help"
echo  "    curl -sSL https://raw.githubusercontent.com/jameszeroX/XKeen/main/install.sh | sh -s -- --stable"
}

# Дубль функции из scripts/_xkeen/01_info/01_info_common.sh: install.sh
# запускается до установки модулей и своих копий-файлов не подключает,
# поэтому правки нужны в обоих местах. Разбор состоянием, а не регуляркой —
# регулярка не отличает комментарий от строкового значения (см. обоснование
# в оригинале).
strip_json_comments() {
    awk '
    {
        line = ""; i = 1; n = length($0); instr = 0; esc = 0
        while (i <= n) {
            c = substr($0, i, 1)
            if (inblk) {
                if (c == "*" && substr($0, i + 1, 1) == "/") { inblk = 0; i += 2 } else i++
                continue
            }
            if (instr) {
                line = line c
                if (esc) esc = 0
                else if (c == "\\") esc = 1
                else if (c == "\"") instr = 0
                i++
                continue
            }
            if (c == "\"") { instr = 1; line = line c; i++; continue }
            if (c == "/" && substr($0, i + 1, 1) == "*") { inblk = 1; i += 2; continue }
            if (c == "/" && substr($0, i + 1, 1) == "/") break
            line = line c; i++
        }
        print line
    }' "$@"
}

# Функция извлечения пользовательского прокси из /opt/etc/xkeen/xkeen.json
get_user_proxy() {
    gh_proxy_user=""
    [ ! -f "$xkeen_config" ] && return 1

    gh_proxy_user=$(strip_json_comments "$xkeen_config" | \
        sed -n 's/.*"gh_proxy"[[:space:]]*: *"\([^"]*\)".*/\1/p' | \
        sed 's/^[[:space:]]*//; s/[[:space:]]*$//' 2>/dev/null)

    [ "$gh_proxy_user" = "null" ] && gh_proxy_user=""
    [ -z "$gh_proxy_user" ] && return 1

    gh_proxy_user="${gh_proxy_user%/}"
    return 0
}

# Функция проверки доступности версии
check_version_available() {
    local test_url="$1"
    curl -sI -f --connect-timeout 3 -m 7 "$test_url" >/dev/null && return 0

    if [ -n "$gh_proxy_user" ]; then
        curl -sI -f --connect-timeout 3 -m 7 "$gh_proxy_user/$test_url" >/dev/null && return 0
    fi

    curl -sI -f --connect-timeout 3 -m 7 "https://gh-proxy.com/$test_url" >/dev/null || \
    curl -sI -f --connect-timeout 3 -m 7 "https://ghfast.top/$test_url" >/dev/null
}

# Функция загрузки XKeen
download_xkeen_release() {
    if curl -fLo "$archive_name" --connect-timeout 10 -m 15 "$1"; then
        return 0
    fi

    if [ -n "$gh_proxy_user" ] && curl -fLo "$archive_name" --connect-timeout 10 -m 15 "$gh_proxy_user/$1"; then
        return 0
    fi

    if curl -fLo "$archive_name" --connect-timeout 10 -m 15 "https://gh-proxy.com/$1"; then
        return 0
    fi

    if curl -fLo "$archive_name" --connect-timeout 10 -m 15 "https://ghfast.top/$1"; then
        return 0
    fi

    printf "  ${red}Ошибка${reset}: не удалось загрузить ${yellow}xkeen.tar.gz${reset}\n"
    return 1
}

# Best-effort проверка SHA-256 скачанного архива через GitHub Releases API.
# Только для --stable/--legacy: URL распознаётся по шаблону releases/latest
# или releases/download/<тег> — это настоящие GitHub Release assets, у
# которых API отдаёт digest. Для --beta (raw.githubusercontent.com/.../test/)
# шаблон не совпадает, функция тихо возвращает успех — как и self-update
# (см. 02_downloaders_xkeen.sh: dev-канал раздаётся сырым файлом, без тега
# и без API digest, проверять там нечего).
#
# Деградирует в предупреждение (не блокирует установку), если недоступны
# jq, GitHub API (напрямую и через оба зеркала) или сам digest в ответе —
# тот же дух, что verify_downloads=warn по умолчанию в 00_fetch_with_mirrors.sh.
# jq устанавливается позже, внутри xkeen -i — на первой чистой установке его
# ещё нет, автоустановку через opkg здесь сознательно не делаем.
verify_install_sha256() {
    _vis_file="$1"
    _vis_url="$2"
    _vis_asset=$(basename "$_vis_url")

    _vis_api_url=$(printf '%s' "$_vis_url" | \
        sed -n 's#^https://github\.com/\([^/]*\)/\([^/]*\)/releases/download/\([^/]*\)/.*#https://api.github.com/repos/\1/\2/releases/tags/\3#p')
    if [ -z "$_vis_api_url" ]; then
        _vis_api_url=$(printf '%s' "$_vis_url" | \
            sed -n 's#^https://github\.com/\([^/]*\)/\([^/]*\)/releases/latest/download/.*#https://api.github.com/repos/\1/\2/releases/latest#p')
    fi

    # URL не похож на GitHub Release asset (--beta) — проверка не для нас
    [ -z "$_vis_api_url" ] && return 0

    if ! command -v jq >/dev/null 2>&1; then
        printf "  ${yellow}Предупреждение${reset}: jq не установлен, проверка контрольной суммы ${light_blue}SHA-256${reset} пропущена\n"
        return 0
    fi

    _vis_ref="${_vis_file}.sha256ref.$$"
    if ! curl -fLsS --connect-timeout 10 -m 15 -o "$_vis_ref" "$_vis_api_url"; then
        if [ -n "$gh_proxy_user" ] && curl -fLsS --connect-timeout 10 -m 15 -o "$_vis_ref" "$gh_proxy_user/$_vis_api_url"; then
            :
        elif curl -fLsS --connect-timeout 10 -m 15 -o "$_vis_ref" "https://gh-proxy.com/$_vis_api_url"; then
            :
        elif curl -fLsS --connect-timeout 10 -m 15 -o "$_vis_ref" "https://ghfast.top/$_vis_api_url"; then
            :
        else
            rm -f "$_vis_ref"
            printf "  ${yellow}Предупреждение${reset}: GitHub API недоступен, проверка контрольной суммы ${light_blue}SHA-256${reset} пропущена\n"
            return 0
        fi
    fi

    _vis_expected=$(jq -r --arg asset "$_vis_asset" '.assets[]? | select(.name == $asset) | .digest // ""' "$_vis_ref" 2>/dev/null | head -n 1)
    rm -f "$_vis_ref"

    case "$_vis_expected" in
        sha256:*) _vis_expected="${_vis_expected#sha256:}" ;;
    esac

    case "$_vis_expected" in
        [0-9a-fA-F][0-9a-fA-F]*) ;;
        *)
            printf "  ${yellow}Предупреждение${reset}: контрольная сумма ${light_blue}SHA-256${reset} не найдена в GitHub API, проверка пропущена\n"
            return 0
            ;;
    esac

    if ! command -v sha256sum >/dev/null 2>&1; then
        printf "  ${yellow}Предупреждение${reset}: sha256sum не установлен, проверка контрольной суммы ${light_blue}SHA-256${reset} пропущена\n"
        return 0
    fi

    _vis_actual=$(sha256sum "$_vis_file" 2>/dev/null | awk '{print $1}')
    if [ "$_vis_actual" = "$_vis_expected" ]; then
        printf "  Контрольная сумма ${light_blue}SHA-256${reset} файла %s ${green}проверена${reset}\n" "$_vis_asset"
        return 0
    fi

    printf "  ${red}Ошибка${reset}: контрольная сумма ${light_blue}SHA-256${reset} файла %s не совпала с ожидаемой\n" "$_vis_asset"
    return 1
}

# RCI-токен (только KeeneticOS 5.2 и новее)
rci_probe_code() {
    if [ -n "$1" ]; then
        curl --noproxy '*' --connect-timeout 2 -m 5 -ksS -o /dev/null -w "%{http_code}" -H "X-Ndma-Tkn: $1" "127.0.0.1:79/rci/show/version" 2>/dev/null
    else
        curl --noproxy '*' --connect-timeout 2 -m 5 -ksS -o /dev/null -w "%{http_code}" "127.0.0.1:79/rci/show/version" 2>/dev/null
    fi
}

# Проба с перепроверкой 401/403 (до 3 попыток), остальные коды возвращаются сразу
rci_probe_code_retry() {
    _rpr_i=0
    _rpr_code=""
    while [ "$_rpr_i" -lt 3 ]; do
        _rpr_code=$(rci_probe_code "$1")
        case "$_rpr_code" in
            401|403) _rpr_i=$((_rpr_i + 1)); [ "$_rpr_i" -lt 3 ] && sleep 1 ;;
            *) break ;;
        esac
    done
    printf '%s' "$_rpr_code"
}

# Версия прошивки
get_keenetic_release() {
    if [ -n "$1" ]; then
        curl -s --noproxy '*' --connect-timeout 3 -m 5 -H "X-Ndma-Tkn: $1" 127.0.0.1:79/rci/show/version 2>/dev/null
    else
        curl -s --noproxy '*' --connect-timeout 3 -m 5 127.0.0.1:79/rci/show/version 2>/dev/null
    fi | sed -n 's/.*"release"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

is_firmware_52_or_newer() {
    printf '%s\n' "$1" | awk -F. '{ exit !(($1 + 0 > 5) || ($1 + 0 == 5 && $2 + 0 >= 2)) }'
}

# Берём значение токена из вывода генерации
extract_rci_token() {
    printf '%s\n' "$1" | awk '
        found { gsub(/^[ \t\r]+|[ \t\r]+$/, ""); if ($0 != "") { print; exit } next }
        /^[ \t]*value:/ {
            sub(/^[ \t]*value:[ \t]*/, ""); gsub(/[ \t\r]+$/, "")
            if ($0 != "") { print; exit }
            found = 1
        }'
}

# Текущее значение rci_token из xkeen.json
get_rci_token_from_config() {
    [ -f "$xkeen_config" ] || return 1
    strip_json_comments "$xkeen_config" | \
        sed -n 's/.*"rci_token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

# Записываем токен в xkeen.json:
#  - файла нет                  -> создаётся минимальный файл только с rci_token;
#  - параметр rci_token есть    -> меняется значение если не валидно;
#  - параметра нет              -> добавляется первой строкой объекта "xkeen"
write_rci_token() {
    _wrt_token="$1"

    if [ ! -f "$xkeen_config" ]; then
        mkdir -p "$(dirname "$xkeen_config")" || return 1
        cat > "$xkeen_config" <<EOF
{
  "xkeen": {
    "rci_token": "$_wrt_token"
  }
}
EOF
        return $?
    fi

    _wrt_tmp="${xkeen_config}.tmp.$$"

    _wrt_rc=0

    if strip_json_comments "$xkeen_config" | grep -q '"rci_token"'; then
        awk -v tok="$_wrt_token" '
            !done && $0 !~ /^[ \t]*\/\// && match($0, /"rci_token"[ \t]*:[ \t]*("[^"]*"|null)/) {
                $0 = substr($0, 1, RSTART - 1) "\"rci_token\": \"" tok "\"" substr($0, RSTART + RLENGTH)
                done = 1
            }
            { print }' "$xkeen_config" > "$_wrt_tmp" || _wrt_rc=1
    else
        awk -v tok="$_wrt_token" '
            { lines[NR] = $0 }
            END {
                for (i = 1; i <= NR; i++) {
                    if (lines[i] !~ /^[ \t]*\/\// && lines[i] ~ /"xkeen"[ \t]*:[ \t]*\{[ \t\r]*$/) { open = i; break }
                }
                if (!open) exit 2
                comma = ","
                for (j = open + 1; j <= NR; j++) {
                    if (lines[j] ~ /^[ \t\r]*$/ || lines[j] ~ /^[ \t]*\/\//) continue
                    if (lines[j] ~ /^[ \t]*\}/) comma = ""
                    break
                }
                for (i = 1; i <= NR; i++) {
                    print lines[i]
                    if (i == open) printf "    \"rci_token\": \"%s\"%s\n", tok, comma
                }
            }' "$xkeen_config" > "$_wrt_tmp" || _wrt_rc=1
    fi

    # cat > вместо mv — сохраняем права и владельца исходного файла
    if [ "$_wrt_rc" -eq 0 ] && [ -s "$_wrt_tmp" ] && cat "$_wrt_tmp" > "$xkeen_config"; then
        rm -f "$_wrt_tmp"
    else
        rm -f "$_wrt_tmp"
        return 1
    fi

    [ "$(get_rci_token_from_config)" = "$_wrt_token" ]
}

rci_token_manual_hint() {
    printf "  Создайте токен ${yellow}вручную${reset} в веб-интерфейсе роутера и впишите его в параметр\n"
    printf "  ${light_blue}\"rci_token\"${reset} файла ${yellow}%s${reset}\n\n" "$xkeen_config"
}

# Проверка/генерация токена и запись его в xkeen.json
setup_rci_token() {
    _srt_old=$(get_rci_token_from_config)
    _srt_code=$(rci_probe_code_retry "$_srt_old")

    if [ -n "$_srt_old" ]; then
        case "$_srt_code" in
            401|403)
                printf "  RCI роутера отклонил ${light_blue}rci_token${reset} из ${yellow}%s${reset} (HTTP %s), создаём новый\n" "$xkeen_config" "$_srt_code"
                ;;
            000|"")
                return 0
                ;;
            *)
                printf "  ${light_blue}rci_token${reset} из ${yellow}%s${reset} ${green}действителен${reset}, генерация пропущена\n\n" "$xkeen_config"
                return 0
                ;;
        esac
    else
        case "$_srt_code" in
            401|403)
                printf "  RCI роутера требует ${yellow}токен доступа${reset} (HTTP %s)\n" "$_srt_code"
                ;;
            200)
                _srt_release=$(get_keenetic_release "")
                [ -z "$_srt_release" ] && return 0
                is_firmware_52_or_newer "$_srt_release" || return 0     # токен нужен только на 5.2
                printf "  Обнаружена прошивка KeeneticOS ${light_blue}%s${reset}, требуется ${yellow}RCI-токен${reset}\n" "$_srt_release"
                ;;
            *)
                return 0
                ;;
        esac
    fi

    if ! command -v ndmc >/dev/null 2>&1; then
        printf "  ${red}Ошибка${reset}: утилита ${yellow}ndmc${reset} не найдена, токен не создан\n"
        rci_token_manual_hint
        return 0
    fi

    _srt_out=$(ndmc -c 'authentication token generate XKeen' 2>&1)
    _srt_token=$(extract_rci_token "$_srt_out")

    case "$_srt_token" in
        ""|*[!A-Za-z0-9._~+/=-]*)
            printf "  ${red}Ошибка${reset}: не удалось сгенерировать токен автоматически\n"
            case "$_srt_out" in
                *"invalid username"*)
                    printf "  Пользователю ${yellow}admin${reset} должны быть выданы права на ${yellow}«Веб-конфигуратор»${reset}\n"
                    printf "  (даже если создан другой пользователь с правами администратора)\n"
                    ;;
                *)
                    printf "  Команда ${yellow}ndmc -c${reset} работает только в нативной SSH-консоли роутера,\n"
                    printf "  при входе через telnet и ${yellow}exec sh${reset} она недоступна\n"
                    ;;
            esac
            rci_token_manual_hint
            return 0
            ;;
    esac

    if write_rci_token "$_srt_token"; then
        printf "  ${green}RCI-токен создан${reset} и записан в ${yellow}%s${reset}\n" "$xkeen_config"
        case "$(rci_probe_code_retry "$_srt_token")" in
            401|403) printf "  ${yellow}Предупреждение${reset}: RCI пока не принимает новый токен, проверьте его вручную\n" ;;
        esac
        echo
    else
        printf "  ${red}Ошибка${reset}: токен создан, но не удалось записать его в ${yellow}%s${reset}\n" "$xkeen_config"
        printf "  Добавьте вручную в объект \"xkeen\": ${light_blue}\"rci_token\": \"%s\"${reset}\n\n" "$_srt_token"
    fi
    return 0
}

is_keenetic_52() {
    _ik_token=$(get_rci_token_from_config)
    _ik_code=$(rci_probe_code_retry "$_ik_token")
    case "$_ik_code" in
        401|403)
            return 0
            ;;
        200)
            _ik_release=$(get_keenetic_release "$_ik_token")
            [ -n "$_ik_release" ] && is_firmware_52_or_newer "$_ik_release"
            return $?
            ;;
        *)
            return 1
            ;;
    esac
}

# Предупреждение об установке Legacy-версии XKeen на KeeneticOS 5.2
warn_legacy_on_52() {
    if is_keenetic_52; then
        printf "  ${red}Внимание!${reset} Обнаружена прошивка ${yellow}KeeneticOS 5.2${reset}\n"
        printf "  Установка предыдущих (Legacy) версий XKeen на KeeneticOS 5.2 осуществляется\n"
        printf "  ${red}целиком и полностью на ваше усмотрение и под вашу ответственность${reset}.\n"
        printf "  Разработчик не несёт никакой ответственности за ваш выбор и его последствия\n\n"
        return 0
    fi
    return 1
}

# Функция загрузки с проверкой (дубль из scripts/_xkeen/.../01_tests_system.sh:
# install.sh запускается до установки модулей, поэтому правки нужны в обоих местах)
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

# Функция проверки доступности репозитория Entware.
# Выполняется до начала установки: при недоступности репозитория
# установка прерывается, чтобы не оставить систему в полуустановленном состоянии.
check_entware_repo() {
    printf "  ${yellow}Проверка готовности${reset} к установке. Пожалуйста, подождите...\n"

    repo_url=$(awk '/^src/ {print $3; exit}' /opt/etc/opkg.conf 2>/dev/null)

    if [ -z "$repo_url" ]; then
        printf "  ${red}Не удалось${reset} определить используемый репозиторий Entware\n"
        printf "  Проверьте файл ${yellow}/opt/etc/opkg.conf${reset}\n"
        exit 1
    fi

    tmp_file="/tmp/pkg_check_$$"

    if download_with_check "$repo_url/Packages.gz" "$tmp_file"; then
        rm -f "$tmp_file" 2>/dev/null
        clear && echo
        return 0
    fi

    rm -f "$tmp_file" 2>/dev/null
    printf "  Репозиторий Entware ${red}недоступен${reset}\n"
    printf "  Установка ${red}прервана${reset}. Выберите рабочее зеркало по ссылке ${light_blue}https://entware.net/mirrors.html${reset}\n"
    printf "  и укажите его в файле ${yellow}/opt/etc/opkg.conf${reset}, после чего запустите установку повторно\n"
    exit 1
}

# Парсинг аргументов командной строки
VERSION_TYPE=""
LEGACY_VERSION=""

while [ $# -gt 0 ]; do
    case "$1" in
        -s|--stable)
            VERSION_TYPE="stable"
            shift
            ;;
        -b|--beta)
            VERSION_TYPE="beta"
            shift
            ;;
        -l|--legacy)
            VERSION_TYPE="legacy"
            LEGACY_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            printf "  ${red}Неизвестный параметр${reset}: $1\n"
            show_help
            exit 1
            ;;
    esac
done

[ -t 1 ] && clear
echo

# Проверяем доступность репозитория Entware до начала установки
check_entware_repo

# Проверяем наличие пользовательского прокси в конфиге
if get_user_proxy; then
    printf "  Используется ${green}пользовательский прокси${reset}: ${yellow}%s${reset}\n\n" "$gh_proxy_user"
fi

# Если параметры не переданы, показываем интерактивное меню
if [ -z "$VERSION_TYPE" ]; then
    while true; do
        printf "  Какую версию ${yellow}XKeen${reset} вы хотите установить?\n\n"
        printf "  1) Стабильную версию (${light_blue}Stable${reset})\n"
        printf "  2) Новую Бета-версию (${light_blue}Beta${reset})\n"
        printf "  3) Предыдущую версию (${light_blue}Legacy${reset})\n\n"
        printf "  0) Отмена\n\n"
        printf "  Выберите пункт меню [по умолчанию 1]: "
        read -r version_choice

        # Если пользователь просто нажал Enter, выбираем 1
        [ -z "$version_choice" ] && version_choice=1

        case "$version_choice" in
            0)
                printf "\n  Установка отменена.\n"
                exit 0
                ;;
            1)
                url="$url_stable"
                echo
                printf "  Выбрана ${light_blue}Стабильная версия${reset}\n"
                break
                ;;
            2)
                url="$url_beta"
                echo
                printf "  Выбрана ${light_blue}Бета-версия${reset}\n"
                break
                ;;
            3)
                echo
                legacy_warned=0
                warn_legacy_on_52 && legacy_warned=1
                while true; do
                    if [ "$legacy_warned" -eq 0 ]; then
                        printf "  ${red}Внимание!${reset}\n  Предыдущие версии могут быть несовместимы с новыми прошивками\n"
                        printf "  Продолжайте только если уверены в том, что делаете\n\n"
                    fi
                    printf "  Введите интересующую версию XKeen (например, ${light_blue}1.1.3.9${reset} или ${light_blue}0${reset} для выхода): "
                    read -r legacy_version

                    if [ -z "$legacy_version" ]; then
                        printf "  ${red}Ошибка${reset}: версия не может быть пустой.\n\n"
                        continue
                    fi

                    [ "$legacy_version" = 0 ] && exit 0

                    url="https://github.com/jameszeroX/XKeen/releases/download/${legacy_version}/xkeen.tar.gz"
                    
                    printf "  Проверяем доступность версии ${yellow}%s${reset}...\n" "$legacy_version"
                    
                    # Быстрая проверка существования файла через HEAD-запрос
                    if check_version_available "$url"; then
                        break 2
                    else
                        printf "  ${red}Ошибка${reset}: версия ${yellow}%s${reset} не найдена в репозитории или недоступна.\n\n" "$legacy_version"
                    fi
                done
                ;;
            *)
                [ -t 1 ] && clear
                printf "\n  ${red}Неверный выбор.${reset} Пожалуйста, выберите пункт от 0 до 3.\n\n"
                ;;
        esac
    done
else
    # Автоматический режим с параметрами командной строки
    case "$VERSION_TYPE" in
        stable)
            url="$url_stable"
            printf "  Выбрана ${light_blue}Стабильная версия${reset} (автоматическая установка)\n"
            ;;
        beta)
            url="$url_beta"
            printf "  Выбрана ${light_blue}Бета-версия${reset} (автоматическая установка)\n"
            ;;
        legacy)
            if [ -z "$LEGACY_VERSION" ]; then
                printf "  ${red}Ошибка${reset}: для параметра --legacy необходимо указать версию\n"
                echo
                show_help
                exit 1
            fi
            warn_legacy_on_52
            url="https://github.com/jameszeroX/XKeen/releases/download/${LEGACY_VERSION}/xkeen.tar.gz"
            printf "  Выбрана предыдущая версия ${yellow}%s${reset} (автоматическая установка)\n" "$LEGACY_VERSION"
            printf "  Проверяем доступность версии ${yellow}%s${reset}...\n" "$LEGACY_VERSION"
            
            if ! check_version_available "$url"; then
                printf "  ${red}Ошибка${reset}: версия ${yellow}%s${reset} не найдена в репозитории или недоступна.\n" "$LEGACY_VERSION"
                exit 1
            fi
            printf "  ${green}Версия найдена${reset}, продолжаем установку...\n"
            ;;
        *)
            printf "  ${red}Неизвестный тип версии${reset}\n"
            exit 1
            ;;
    esac
fi

echo

setup_rci_token

if ! download_xkeen_release "$url"; then
    exit 1
fi

if ! verify_install_sha256 "$archive_name" "$url"; then
    rm -f "$archive_name"
    exit 1
fi

stage_dir="/opt/sbin/.xkeen-install.$$"
rm -rf "$stage_dir"
mkdir -p "$stage_dir"
if ! tar -xzf "$archive_name" -C "$stage_dir" || [ ! -f "$stage_dir/xkeen" ] || [ ! -d "$stage_dir/_xkeen" ]; then
    rm -rf "$stage_dir"
    rm -f "$archive_name"
    printf "  ${red}Ошибка${reset}: не удалось распаковать ${yellow}xkeen.tar.gz${reset}\n"
    exit 1
fi

rm -f "$archive_name"

chmod +x "$stage_dir/xkeen"
if ! mv "$stage_dir/xkeen" /opt/sbin/xkeen.new; then
    rm -rf "$stage_dir" /opt/sbin/xkeen.new
    printf "  ${red}Ошибка${reset}: после распаковки не найден исполняемый файл ${yellow}/opt/sbin/xkeen${reset}\n"
    exit 1
fi
rm -f /opt/sbin/xkeen.old
if [ -f /opt/sbin/xkeen ] && ! mv /opt/sbin/xkeen /opt/sbin/xkeen.old; then
    rm -rf "$stage_dir" /opt/sbin/xkeen.new
    printf '  %sОшибка%s: не удалось сохранить установленный XKeen\n' "$red" "$reset"
    exit 1
fi
if ! mv /opt/sbin/xkeen.new /opt/sbin/xkeen; then
    [ -f /opt/sbin/xkeen.old ] && mv /opt/sbin/xkeen.old /opt/sbin/xkeen
    rm -rf "$stage_dir" /opt/sbin/xkeen.new
    printf "  ${red}Ошибка${reset}: после распаковки не найден исполняемый файл ${yellow}/opt/sbin/xkeen${reset}\n"
    exit 1
fi
rm -rf /opt/sbin/.xkeen.old
if [ -d /opt/sbin/.xkeen ] && ! mv /opt/sbin/.xkeen /opt/sbin/.xkeen.old; then
    if [ -f /opt/sbin/xkeen.old ]; then
        mv /opt/sbin/xkeen.old /opt/sbin/xkeen
    else
        rm -f /opt/sbin/xkeen
    fi
    rm -rf "$stage_dir"
    printf '  %sОшибка%s: не удалось сохранить установленные модули XKeen\n' "$red" "$reset"
    exit 1
fi
if ! mv "$stage_dir/_xkeen" /opt/sbin/.xkeen; then
    [ -f /opt/sbin/xkeen.old ] && mv /opt/sbin/xkeen.old /opt/sbin/xkeen
    [ -d /opt/sbin/.xkeen.old ] && mv /opt/sbin/.xkeen.old /opt/sbin/.xkeen
    rm -rf "$stage_dir"
    printf "  ${red}Ошибка${reset}: не удалось установить модули XKeen\n"
    exit 1
fi
rm -f /opt/sbin/xkeen.old
rm -rf /opt/sbin/.xkeen.old "$stage_dir"

exec /opt/sbin/xkeen -i