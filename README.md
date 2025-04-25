# Xray-Keenetic
Origin <https://github.com/Skrill0/XKeen>

FAQ <https://jameszero.net/faq-xkeen.htm>

Telegram <https://t.me/+SZWOjSlvYpdlNmMy> (обсуждение, инструкции по установке, советы по использованию)

## Версия 1.1.3.4

Сравнение форка с оригинальным XKeen

Изменения:
- XKeen устанавливает крайнюю версию xray-core и проверяет обновления по расписанию (ранее устанавливалась зафиксированная версия 1.8.4)
- Исправлено добавление портов в исключения (ранее команду `xkeen -ape` нужно было прерывать по ctrl+c)
- Исправлена совместная работа режима TProxy и socks5 (ранее Xkeen запускался в Mixed режиме, что приводило к неработоспособности)
- Исправлен автозапуск XKeen при старте роутера (ранее XKeen иногда не запускался или запускался для всего устройства, а не только для своей политики - [FAQ п.12](https://jameszero.net/faq-xkeen.htm#12))
- Объединены задачи планировщика по обновлению GeoSite и GeoIP. В связи с этим упразднены параметры командной строки: `-ugs`, `-ugi`, `-ugsc`, `-ugic`, `-dgsc`, `-dgic`
- Корректная деинсталляция xray-core (ранее пакет xray не удалялся при деинсталляции)
- Справка (`xkeen -h`) выровнена по табуляции и повышен контраст текста
- Косметические и функциональные правки скриптов
- Актуализация конфигурационных файлов xray-core

Добавлено:
- Возможность [OffLine установки](https://github.com/jameszeroX/XKeen/blob/main/OffLine_install.md) (параметр `-io`)
- Возможность установки GeoIP базы [zkeenip.dat](https://github.com/jameszeroX/zkeen-ip)
- Обновление [zkeen.dat](https://github.com/jameszeroX/zkeen-domains) и [zkeenip.dat](https://github.com/jameszeroX/zkeen-ip) по расписанию средствами XKeen
- Параметр командной строки `-remove` для полной деинсталляции XKeen (ранее деинсталляцию нужно было выполнять покомпонентно)
- Параметры командной строки: `-ug` (обновление геофайлов), `-ugc` (управление заданием Cron, обновляющим геофайлы), `-dgc` (удаление задания Cron, обновляющего геофайлы)

Удалено:
- Возможность установки GeoSite Antizapret (база повреждена в репозитории)
- Конфигурационный файл transport.json (не используется новыми ядрами xray-core)

## Порядок установки
```
opkg install curl
curl -OfL https://raw.githubusercontent.com/jameszeroX/XKeen/main/install.sh && chmod +x ./install.sh
./install.sh
```
Альтернативный вариант установки:
```
opkg install ca-certificates wget-ssl tar
wget "https://cdn.jsdelivr.net/gh/jameszeroX/XKeen@main/xkeen.tar" && tar -xvf xkeen.tar -C /opt/sbin --overwrite > /dev/null && rm xkeen.tar
xkeen -i
```

## Поддержка
Желающие угостить меня пивом, такую возможность имеют)
- Монета USDT, сеть TRC20:
```
TB9dLwzNdLB6QeKV6w4FjCACSarePb32Dg
```
- Монета USDT, сеть TON:
```
UQDHmmyz0e1K07Wf7aTVtdmcGzCPfo4Pf7uBi_Id8TDI6Da6
```
[ЮMoney](https://yoomoney.ru/to/41001350776240)

[CloudTips](https://pay.cloudtips.ru/p/7edb30ec)
