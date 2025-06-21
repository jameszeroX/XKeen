**1.1.3.8 Pre**

- Исправление обнаруженных багов, добавление новых)


Порядок установки с нуля:
```
opkg update && opkg upgrade && opkg install curl tar
curl -OL https://raw.githubusercontent.com/jameszeroX/xkeen/main/test/xkeen.tar.gz
c="tar -xvzf xkeen.tar.gz -C /opt/sbin >/dev/null 2>&1";$c --overwrite || $c && rm xkeen.tar.gz
xkeen -i
```

Порядок осбовления с предыдущей версии:
```
opkg update && opkg upgrade && opkg install curl tar
curl -OL https://raw.githubusercontent.com/jameszeroX/xkeen/main/test/xkeen.tar.gz
c="tar -xvzf xkeen.tar.gz -C /opt/sbin >/dev/null 2>&1";$c --overwrite || $c && rm xkeen.tar.gz
xkeen -k
```

Обсудить XKeen и сообщить об ошибках можно в телеграм-чате https://t.me/+SZWOjSlvYpdlNmMy
