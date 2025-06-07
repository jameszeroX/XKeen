**Release Candidate**

- Добавлена поддержка ядра Mihomo в режиме TProxy
- Сменить ядро после установки можно параметрами `-mihomo` и `-xray`
- Обновление ядра Mihomo после установки выполняется параметром `-um`
- Для XKeen, Xray и Mihomo добавлен резервный источник релизов на случай недоступности GitHub API
- Переработана логика загрузки GeoFile's из интернета, уменьшающая вероятность их повреждения
- Переработана логика применения правил iptables и ip6tables (ранее XKeen применял все правила даже при не установленном компоненте IPv6)
- Удалён запрос на перезапись и сама перезапись конфигурационных файлов xray, если они уже существуют на момент установки XKeen
- Удалено создание резервных копий xray и его конфигурации, так как теперь можно интерактивно установить предыдущую версию ядра параметром `-ux`. В связи с этим упразднены параметры запуска `-xb`, `-cb`, `-xbr`, `-cbr`

Порядок установки:
```
opkg update && opkg upgrade && opkg install curl tar
curl -L https://raw.githubusercontent.com/jameszeroX/xkeen/main/test/xkeen.tar.gz -o xkeen.tar.gz
tar -xvzf xkeen.tar.gz -C /opt/sbin --overwrite > /dev/null && rm xkeen.tar.gz
xkeen -i
```

Обсудить работу XKeen и сообщить об ошибках beta-версии можно в телеграм-чате https://t.me/+SZWOjSlvYpdlNmMy
