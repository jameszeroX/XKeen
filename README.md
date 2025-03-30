# Xray-Keenetic
Форк проекта https://github.com/Skrill0/XKeen

Версия 1.1.3.1

Изменения:
- XKeen устанавливает крайнюю версию xray-core и обновляет её при необходимости (ранее устанавливалась зафиксированная версия 1.8.4)
- Исправлено добавление портов в исключения (ранее команду xkeen -ape нужно было прерывать по ctrl+c)
- Исправлена совместная работа режима TProxy и socks5 (ранее Xkeen запускался в Mixed режиме, что приводило к неработоспособности)
- Актуализация конфигурационных файлов xray-core

Добавлено:
- Возможность установки GeoIP базы zkeenip.dat
- Обновление zkeen.dat и zkeenip.dat по расписанию средствами XKeen

Удалено:
- GeoSite Antizapret (база повреждена в репозитории)
- Конфигурационный файл transport.json (не используется новыми ядрами xray-core)

Порядок установки:
```
opkg install curl
curl -sOfL https://raw.githubusercontent.com/jameszeroX/XKeen/main/install.sh
chmod +x ./install.sh
./install.sh
```
