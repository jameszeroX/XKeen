#!/bin/sh

url="https://github.com/jameszeroX/XKeen/releases/latest/download/xkeen.tar.gz"
archive_name="xkeen.tar.gz"

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

exec /opt/sbin/xkeen -i
