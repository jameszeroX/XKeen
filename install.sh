#!/bin/sh

green="\033[92m"
red="\033[91m"
yellow="\033[93m"
light_blue="\033[96m"
reset="\033[0m"

url_stable="https://github.com/jameszeroX/XKeen/releases/latest/download/xkeen.tar.gz"
url_beta="https://raw.githubusercontent.com/jameszeroX/XKeen/main/test/xkeen.tar.gz"
url_var_file="https://raw.githubusercontent.com/jameszeroX/XKeen/main/01_info_variable.sh"
archive_name="xkeen.tar.gz"

clear
echo
printf "  Какую версию ${yellow}XKeen${reset} вы хотите установить?\n\n"
printf "  1) Стабильную версию (${light_blue}Stable${reset})\n"
printf "  2) Новую Бета-версию (${light_blue}Beta${reset})\n\n"
printf "  Выберите 1 или 2 [по умолчанию 1]: "
read -r version_choice

case "$version_choice" in
    2)
        url="$url_beta"
        echo
        printf "  Выбрана ${light_blue}Бета-версия${reset}\n"
        ;;
    *)
        url="$url_stable"
        echo
        printf "  Выбрана ${light_blue}Стабильная версия${reset}\n"
        ;;
esac
echo

download_with_fallback() {
    _target="$1"
    _url="$2"

    if curl -fLo "$_target" --connect-timeout 10 -m 180 "$_url"; then
        return 0
    fi
    if curl -fLo "$_target" --connect-timeout 10 -m 180 "https://gh-proxy.com/$_url"; then
        return 0
    fi
    if curl -fLo "$_target" --connect-timeout 10 -m 180 "https://ghfast.top/$_url"; then
        return 0
    fi
    return 1
}

download_xkeen_release() {
    if ! download_with_fallback "$archive_name" "$url"; then
        printf "  ${red}Ошибка${reset}: не удалось загрузить ${yellow}xkeen.tar.gz${reset}\n"
        return 1
    fi
}

get_release_var_file() {
    for _path in \
        /opt/sbin/_xkeen/01_info/01_info_variable.sh \
        /opt/sbin/.xkeen/01_info/01_info_variable.sh
    do
        [ -f "$_path" ] && printf '%s\n' "$_path" && return 0
    done
    return 1
}

patch_var_file() {
    _var_file="$(get_release_var_file)" || {
        printf "  ${red}Ошибка${reset}: после распаковки не найден файл ${yellow}01_info_variable.sh${reset}\n"
        return 1
    }
    if ! download_with_fallback "$_var_file" "$url_var_file"; then
        printf "  ${red}Ошибка${reset}: не удалось обновить ${yellow}01_info_variable.sh${reset} из main\n"
        return 1
    fi
}

if ! download_xkeen_release; then
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

if ! patch_var_file; then
    exit 1
fi

exec /opt/sbin/xkeen -i