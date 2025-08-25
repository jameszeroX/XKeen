## Версия 1.1.3.9 Preview

- При обновлении Xray и Mihomo теперь отображается версия уже установленного в роутере бинарника
- Исправлено добавление диапазона портов в исключения проксирования


### Порядок обновления с версии 1.1.3.8
Переключитесь на канал разработки и выполните обновление:
```
xkeen -channel
xkeen -uk
```

### Порядок установки с нуля
```
opkg update && opkg upgrade && opkg install curl tar
curl -OL https://raw.githubusercontent.com/jameszeroX/xkeen/main/test/xkeen.tar.gz
tar -xvzf xkeen.tar.gz -C /opt/sbin > /dev/null && rm xkeen.tar.gz
xkeen -i
```

Обсудить XKeen и сообщить об ошибках тестовой версии можно в телеграм-чате https://t.me/+SZWOjSlvYpdlNmMy