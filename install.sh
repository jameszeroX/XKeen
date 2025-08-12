#!/bin/sh

url="https://github.com/jameszeroX/XKeen/releases/latest/download/xkeen.tar.gz"
if ! curl -OL "$url"; then
    if ! curl -OL "https://ghfast.top/$url"; then
        echo "Ошибка: не удалось загрузить xkeen.tar.gz"
        exit 1
    fi
fi

tar -xvzf xkeen.tar.gz -C /opt/sbin > /dev/null && rm xkeen.tar.gz
xkeen -i
