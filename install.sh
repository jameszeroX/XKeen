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
echo -e "    -p, --patch		${italic}Пропатчить установленную версию для совместимости с KeeneticOS 5.1.2+${reset}"
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

# Функция извлечения пользовательского прокси из /opt/etc/xkeen/xkeen.json
get_user_proxy() {
    gh_proxy_user=""
    [ ! -f "$xkeen_config" ] && return 1

    gh_proxy_user=$(sed \
        -e ':a; s:/\*[^*]*\*[^/]*\*/::g; ta' \
        -e 's/^[[:space:]]*\/\/.*$//' \
        -e 's/[[:space:]]\{1,\}\/\/.*$//' \
        "$xkeen_config" | \
        sed -n 's/.*"gh_proxy"[[:space:]]*: *"\([^"]*\)".*/\1/p' | \
        xargs 2>/dev/null)

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

# Функция патча установленной версии для совместимости с KeeneticOS 5.1.2+
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
    printf "  Патчим файлы для совместимости с ${yellow}KeeneticOS 5.1.2+${reset}...\n\n"

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
        printf "  Патч не потребовался. XKeen совместим с ${yellow}KeeneticOS 5.1.2+${reset} либо не установлен\n"
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

clear
echo

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
        printf "  3) Предыдущую версию (${light_blue}Legacy${reset})\n"
        printf "  4) Пропатчить установленную версию для совместимости с ${yellow}KeeneticOS 5.1.2+${reset}\n\n"
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
                    printf "  ${red}Внимание!${reset} Предыдущие версии ${red}несовместимы${reset} с ${yellow}KeeneticOS 5.1.2+${reset}\n"
                    printf "  Убедитесь, что используете более старую прошивку\n\n"
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
                clear
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

if ! tar -xzf "$archive_name" -C /opt/sbin; then
    rm -f "$archive_name"
    printf "  ${red}Ошибка${reset}: не удалось распаковать ${yellow}xkeen.tar.gz${reset}\n"
    exit 1
fi

rm -f "$archive_name"

if [ ! -x /opt/sbin/xkeen ]; then
    printf "  ${red}Ошибка${reset}: после распаковки не найден исполняемый файл ${yellow}/opt/sbin/xkeen${reset}\n"
    exit 1
fi

exec /opt/sbin/xkeen -i