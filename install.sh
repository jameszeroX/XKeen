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
echo -e "    -p, --patch		${italic}Пропатчить установленную версию для совместимости с KeeneticOS 5.1.2${reset}"
echo -e "    -h, --help		${italic}Показать эту справку${reset}"
echo
echo -e "  ${yellow}Примеры${reset}"
echo  "    $0 --stable"
echo  "    $0 --beta"
echo  "    $0 --legacy 1.1.3.9"
echo  "    $0 --patch"
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

# Функция патча установленной версии для совместимости с KeeneticOS 5.1.2
# (замена "localhost" на "127.0.0.1" в rci-запросах)
patch_localhost_compat() {
    local target_init_dir="/opt/etc/init.d"
    local target_init_files="S05xkeen S99xkeen S24xray"
    local target_dir="/opt/sbin/.xkeen"
    local patched=0
    local found_files
    local init_file
    local init_path

    echo
    printf "  Патчим файлы для совместимости с ${yellow}KeeneticOS 5.1.2${reset}...\n\n"

    for init_file in $target_init_files; do
        init_path="$target_init_dir/$init_file"
        if [ -f "$init_path" ]; then
            if grep -q "localhost" "$init_path" 2>/dev/null; then
                sed -i 's/localhost/127.0.0.1/g' "$init_path"
                printf "  ${green}✓${reset} Обновлён файл: %s\n" "$init_path"
                patched=1
            else
                printf "  Файл %s не требует патча\n" "$init_path"
            fi
        fi
    done

    if [ -d "$target_dir" ]; then
        found_files=$(grep -rl "localhost" "$target_dir" 2>/dev/null)
        if [ -n "$found_files" ]; then
            patched=1
            echo "$found_files" | while IFS= read -r f; do
                sed -i 's/localhost/127.0.0.1/g' "$f"
                printf "  ${green}✓${reset} Обновлён файл: %s\n" "$f"
            done
        else
            printf "  Файлы в папке %s не требуют патча\n" "$target_dir"
        fi
    else
        printf "  ${yellow}Внимание${reset}: папка %s не найдена\n" "$target_dir"
    fi

    echo
    if [ "$patched" -eq 1 ]; then
        printf "  ${green}Патч успешно применён${reset}\n"
    else
        printf "  Патч не потребовался. XKeen совместим с ${yellow}KeeneticOS 5.1.2${reset} либо не установлен\n"
    fi
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
        -p|--patch)
            VERSION_TYPE="patch"
            shift
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

# Проверяем наличие пользовательского прокси в конфиге
if get_user_proxy; then
    printf "  Используется ${green}пользовательский прокси${reset}: ${yellow}%s${reset}\n\n" "$gh_proxy_user"
fi

# Если параметры не переданы, показываем интерактивное меню
if [ -z "$VERSION_TYPE" ]; then
    while true; do
        printf "  Какую версию ${yellow}XKeen${reset} вы хотите установить?\n\n"
        printf "  1) Стабильную версию (${light_blue}Stable${reset}) только для ${yellow}KeeneticOS${reset} ${green}до${reset} ${yellow}5.1.2${reset}\n"
        printf "  2) Новую Бета-версию (${light_blue}Beta${reset})\n"
        printf "  3) Предыдущую версию (${light_blue}Legacy${reset})\n"
        printf "  4) Пропатчить установленную версию для совместимости с ${yellow}KeeneticOS 5.1.2${reset}\n\n"
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
                while true; do
                    printf "  ${red}Внимание!${reset}\n  Предыдущие версии могут быть несовместимы с новыми прошивками\n"
                    printf "  Продолжайте только если уверены в том, что делаете\n\n"
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
            4)
                patch_localhost_compat
                exit 0
                ;;
            *)
                [ -t 1 ] && clear
                printf "\n  ${red}Неверный выбор.${reset} Пожалуйста, выберите пункт от 0 до 4.\n\n"
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
            url="https://github.com/jameszeroX/XKeen/releases/download/${LEGACY_VERSION}/xkeen.tar.gz"
            printf "  Выбрана предыдущая версия ${yellow}%s${reset} (автоматическая установка)\n" "$LEGACY_VERSION"
            printf "  Проверяем доступность версии ${yellow}%s${reset}...\n" "$LEGACY_VERSION"
            
            if ! check_version_available "$url"; then
                printf "  ${red}Ошибка${reset}: версия ${yellow}%s${reset} не найдена в репозитории или недоступна.\n" "$LEGACY_VERSION"
                exit 1
            fi
            printf "  ${green}Версия найдена${reset}, продолжаем установку...\n"
            ;;
        patch)
            patch_localhost_compat
            exit 0
            ;;
        *)
            printf "  ${red}Неизвестный тип версии${reset}\n"
            exit 1
            ;;
    esac
fi

echo

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
[ -f /opt/sbin/xkeen ] && mv /opt/sbin/xkeen /opt/sbin/xkeen.old
if ! mv /opt/sbin/xkeen.new /opt/sbin/xkeen; then
    [ -f /opt/sbin/xkeen.old ] && mv /opt/sbin/xkeen.old /opt/sbin/xkeen
    rm -rf "$stage_dir" /opt/sbin/xkeen.new
    printf "  ${red}Ошибка${reset}: после распаковки не найден исполняемый файл ${yellow}/opt/sbin/xkeen${reset}\n"
    exit 1
fi
rm -rf /opt/sbin/.xkeen.old
[ -d /opt/sbin/.xkeen ] && mv /opt/sbin/.xkeen /opt/sbin/.xkeen.old
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