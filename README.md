# Xray-Keenetic
Origin <https://github.com/Skrill0/XKeen>

FAQ <https://jameszero.net/faq-xkeen.htm>

Telegram <https://t.me/+SZWOjSlvYpdlNmMy> (обсуждение, инструкции по установке, советы по использованию)

## Версия 1.1.3.2

Сравнение форка с оригинальным XKeen

Изменения:
- XKeen устанавливает крайнюю версию xray-core и обновляет её при необходимости (ранее устанавливалась зафиксированная версия 1.8.4)
- Исправлено добавление портов в исключения (ранее команду `xkeen -ape` нужно было прерывать по ctrl+c)
- Исправлена совместная работа режима TProxy и socks5 (ранее Xkeen запускался в Mixed режиме, что приводило к неработоспособности)
- Корректная деинсталляция xray-core (ранее пакет xray не удалялся при деинсталляции)
- Косметические правки скриптов установки и удаления XKeen
- Актуализация конфигурационных файлов xray-core

Добавлено:
- Возможность установки GeoIP базы zkeenip.dat
- Обновление [zkeen.dat](https://github.com/jameszeroX/zkeen-domains) и [zkeenip.dat](https://github.com/jameszeroX/zkeen-ip) по расписанию средствами XKeen
- Ключ командной строки `-remove` для полной деинсталляции XKeen (ранее деинсталляцию нужно было выполнять покомпонентно)

Удалено:
- Возможность установки GeoSite Antizapret (база повреждена в репозитории)
- Конфигурационный файл transport.json (не используется новыми ядрами xray-core)

## Порядок установки:
```
opkg install curl
curl -sOfL https://raw.githubusercontent.com/jameszeroX/XKeen/main/install.sh
chmod +x ./install.sh
./install.sh
```
