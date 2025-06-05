**Beta версия**

- Добавлена базовая поддержка ядра Mihomo
- Поддерживается работа Mihomo только в режиме TProxy
- Сменить ядро после установки можно параметрами `-mihomo` и `-xray`
- Обновление ядра Mihomo после установки выполняется параметром `-um`
- Для Mihomo и Xray добавлен резервный источник релизов
- Переработана логика загрузки GeoFile, уменьшающая вероятность их повреждения
- Переработана логика применения правил iptables и ip6tables (ранее XKeen применял все правила даже при неустановленном компоненте IPv6)
- Корректное обновление с финальной версии до beta не гарантируется. Рекомендуется чистая установка

Порядок установки:
```
opkg update >/dev/null 2>&1
opkg install curl tar
curl -L https://raw.githubusercontent.com/jameszeroX/xkeen/main/beta/xkeen.tar -o xkeen.tar
tar -xvf xkeen.tar -C /opt/sbin --overwrite > /dev/null && rm xkeen.tar
xkeen -i
```

Обсудить работу XKeen и сообщить об ошибках beta-версии можно в телеграм-чате https://t.me/+SZWOjSlvYpdlNmMy
