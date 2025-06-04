**Beta  версия**

- Добавлена базовая поддержка ядра Mihomo
- Поддерживается работа Mihomo только в режиме TProxy
- Сменить ядро после установки можно параметрами `-mihomo` и `-xray`
- Обновление ядра Mihomo после установки выполняется параметром `-um`
- Для Mihomo и Xray добавлен резервный источник релизов
- Бекап конфига и бинарника Mihomo при обновлении не выполняется
- Корректное обновление с финальной версии XKeen не гарантируется. Рекомендуется чистая установка

Порядок установки:
```
opkg install tar
curl -L https://raw.githubusercontent.com/jameszeroX/xkeen/refs/heads/main/beta/xkeen.tar --output xkeen.tar
tar -xvf xkeen.tar -C /opt/sbin --overwrite > /dev/null && rm xkeen.tar
xkeen -i
```
