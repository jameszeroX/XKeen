# Xray-Keenetic
Origin <https://github.com/Skrill0/XKeen>

FAQ <https://jameszero.net/faq-xkeen.htm>

Telegram <https://t.me/+SZWOjSlvYpdlNmMy> (обсуждение, инструкции по установке, советы по использованию)

Xray-core <https://github.com/XTLS/Xray-core>

## Версия 1.1.3.6

Сравнение форка с оригинальным XKeen

Изменения:
- Исправлено добавление портов в исключения (ранее команду `xkeen -ape` нужно было прерывать по ctrl+c)
- Исправлена совместная работа режима TProxy и socks5 (ранее Xkeen запускался в Mixed режиме, что приводило к неработоспособности прозрачного проксирования)
- Исправлен автозапуск XKeen при старте роутера (ранее XKeen иногда не запускался или запускался для всего устройства, а не только для своей политики - [FAQ п.12](https://jameszero.net/faq-xkeen.htm#12))
- Объединены задачи планировщика по обновлению GeoSite и GeoIP. В связи с этим упразднены параметры запуска `-ugs`, `-ugi`, `-ugsc`, `-ugic`, `-dgsc`, `-dgic`
- Корректная деинсталляция xray-core (ранее пакет xray не удалялся при деинсталляции)
- Справка (`xkeen -h`) выровнена по табуляции и повышен контраст текста
- Косметические и функциональные правки скриптов
- Актуализация конфигурационных файлов xray-core

Добавлено:
- Возможность выбрать версию xray при установке XKeen, а так же при использовании параметра `-ux` (поддерживается повышение/понижение версии)
- Возможность [OffLine установки](https://github.com/jameszeroX/XKeen/blob/main/OffLine_install.md) (параметр `-io`)
- Возможность установки GeoIP базы [zkeenip.dat](https://github.com/jameszeroX/zkeen-ip)
- Обновление [zkeen.dat](https://github.com/jameszeroX/zkeen-domains) и [zkeenip.dat](https://github.com/jameszeroX/zkeen-ip) по расписанию средствами XKeen
- Параметр запуска `-remove` для полной деинсталляции XKeen (ранее деинсталляцию нужно было выполнять покомпонентно)
- Параметры запуска `-ug` (обновление геофайлов), `-ugc` (управление заданием Cron, обновляющим геофайлы), `-dgc` (удаление задания Cron, обновляющего геофайлы)
- Возможность контролировать число открытых файловых дескрипторов, используемых процессом xray и перезапускать процесс при исчерпании лимита. По умолчанию контроль отключен (включить/отключить можно запуском `xkeen -fd`), [подробнее](https://github.com/jameszeroX/XKeen/blob/main/FileDescriptors.md)

Удалено:
- Возможность установки GeoSite Antizapret (база повреждена в репозитории)
- Конфигурационный файл transport.json (не используется новыми ядрами xray-core)
- Задачи планировщика по автообновлению XKeen/Xray. В связи с этим упразднены параметры запуска `-uac`, `-ukc`, `-uxc`, `-dac`, `-dkc`, `-dxc`
- Параметры запуска `-x` (функционал заменён параметром `-ux`), `-rc` (не актуален)

## Порядок установки
```
opkg install curl
curl -OfL https://raw.githubusercontent.com/jameszeroX/XKeen/main/install.sh && chmod +x ./install.sh
./install.sh
```
Альтернативный вариант:
```
opkg install ca-certificates wget-ssl tar
wget "https://github.com/jameszeroX/XKeen/releases/latest/download/xkeen.tar" && tar -xvf xkeen.tar -C /opt/sbin --overwrite > /dev/null && rm xkeen.tar
xkeen -i
```
Установка [OffLine](https://github.com/jameszeroX/XKeen/blob/main/OffLine_install.md) 

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
