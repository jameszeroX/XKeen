#!/bin/sh

url="https://github.com/jameszeroX/XKeen/releases/latest/download/xkeen.tar.gz"
archive_name="xkeen.tar.gz"
release_fix_url="https://raw.githubusercontent.com/jameszeroX/XKeen/main/01_info_variable.sh"

get_release_var_file() {
    if [ -f /opt/sbin/_xkeen/01_info/01_info_variable.sh ]; then
        printf '%s\n' "/opt/sbin/_xkeen/01_info/01_info_variable.sh"
        return 0
    fi

    if [ -f /opt/sbin/.xkeen/01_info/01_info_variable.sh ]; then
        printf '%s\n' "/opt/sbin/.xkeen/01_info/01_info_variable.sh"
        return 0
    fi

    return 1
}

download_xkeen_release() {
    if curl -fLo "$archive_name" --connect-timeout 10 -m 180 "$url"; then
        return 0
    fi

    if curl -fLo "$archive_name" --connect-timeout 10 -m 180 "https://gh-proxy.com/$url"; then
        return 0
    fi

    if curl -fLo "$archive_name" --connect-timeout 10 -m 180 "https://ghfast.top/$url"; then
        return 0
    fi

    echo "Ошибка: не удалось загрузить xkeen.tar.gz"
    return 1
}

download_release_fix() {
    target_file="$1"

    if curl -fLo "$target_file" --connect-timeout 10 -m 180 "$release_fix_url"; then
        return 0
    fi

    if curl -fLo "$target_file" --connect-timeout 10 -m 180 "https://gh-proxy.com/$release_fix_url"; then
        return 0
    fi

    if curl -fLo "$target_file" --connect-timeout 10 -m 180 "https://ghfast.top/$release_fix_url"; then
        return 0
    fi

    echo "Ошибка: не удалось применить исправление 01_info_variable.sh для релиза 1.1.3.9"
    return 1
}

apply_release_1139_yq_fix() {
    release_var_file="$(get_release_var_file)" || {
        echo "Ошибка: после распаковки не найден файл 01_info_variable.sh"
        return 1
    }

    release_version=$(sed -n 's/^xkeen_current_version="\([^"]*\)".*/\1/p' "$release_var_file" | head -n 1)
    release_build=$(sed -n 's/^xkeen_build="\([^"]*\)".*/\1/p' "$release_var_file" | head -n 1)

    if [ "$release_version" = "1.1.3.9" ] && [ "$release_build" = "Stable" ]; then
        if ! download_release_fix "$release_var_file"; then
            return 1
        fi
    fi
}

if ! download_xkeen_release; then
    exit 1
fi

if ! tar -xzf "$archive_name" -C /opt/sbin; then
    rm -f "$archive_name"
    echo "Ошибка: не удалось распаковать xkeen.tar.gz"
    exit 1
fi

rm -f "$archive_name"

if [ ! -x /opt/sbin/xkeen ]; then
    echo "Ошибка: после распаковки не найден исполняемый файл /opt/sbin/xkeen"
    exit 1
fi

if ! apply_release_1139_yq_fix; then
    exit 1
fi

exec /opt/sbin/xkeen -i
