#!/bin/sh

url="https://github.com/jameszeroX/XKeen/releases/latest/download/xkeen.tar.gz"
urlfix="https://raw.githubusercontent.com/jameszeroX/xkeen/main/01_info_variable.sh"
if ! curl -OL --connect-timeout 10 -m 60 "$url"; then
    if ! curl -OL --connect-timeout 10 -m 60 "https://gh-proxy.com/$url"; then
        if ! curl -OL --connect-timeout 10 -m 60 "https://ghfast.top/$url"; then
            echo "Ошибка: не удалось загрузить xkeen.tar.gz"
            exit 1
        fi
    fi
fi

tar -xvzf xkeen.tar.gz -C /opt/sbin > /dev/null && rm xkeen.tar.gz
curl -Lo /opt/sbin/_xkeen/01_info/01_info_variable.sh "$urlfix"
xkeen -i
