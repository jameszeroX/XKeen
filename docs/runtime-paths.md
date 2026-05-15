# Раскладка на роутере

Все runtime-пути на роутере. В этом репозитории каталог `_xkeen/`; после установки на роутер он переименовывается в `.xkeen/` функцией `install_xkeen_rename`. Все переменные путей определены в [`scripts/_xkeen/01_info/01_info_variable.sh`](../scripts/_xkeen/01_info/01_info_variable.sh) — не хардкодить.

## Исполняемые файлы и модули

| Путь | Назначение |
| --- | --- |
| `/opt/sbin/xkeen` | Диспетчер (исполняемый, монолитный POSIX-sh) |
| `/opt/sbin/.xkeen/` | Каталог импортируемых модулей XKeen |
| `/opt/sbin/.xkeen/import.sh` | Точка сборки модулей |
| `/opt/etc/init.d/S05xkeen` | Init-скрипт XKeen, генерируется `04_register_init.sh` |
| `/opt/etc/init.d/S05crond` | Cron-демон, обслуживает автообновления geofile |

## Пользовательский конфиг

`/opt/etc/xkeen/` — все настройки, которые правит пользователь.

| Файл | Назначение |
| --- | --- |
| `xkeen.json` | Главный конфиг: `gh_proxy`, политики, расширения 2.0 Beta |
| `ip_exclude.lst` | IP/подсети, исключённые из проксирования (с маской `/32` для одиночных адресов) |
| `port_proxying.lst` | Порты, направляемые в прокси. С 2.0 Beta — единственный источник, старая `port_donor` упразднена |
| `port_exclude.lst` | Порты, исключённые из проксирования. С 2.0 Beta — единственный источник, старая `port_exclude` (как переменная) упразднена |
| `ipset/ru_exclude_ipv4.lst` | IPv4-сеты для российских IP — Beta-функция исключения по ipset |
| `ipset/ru_exclude_ipv6.lst` | То же для IPv6 |

## Конфиги ядер

| Путь | Назначение |
| --- | --- |
| `/opt/etc/xray/configs/` | Все JSON-конфиги Xray (`inbounds.json`, `outbounds.json`, `routing.json`, `dns.json`) |
| `/opt/etc/xray/dat/` | GeoSite (`*.dat`) и GeoIP (`*.dat`) базы |
| `/opt/etc/mihomo/` | Конфигурация Mihomo (`config.yaml` и подключаемые) |

## Логи

| Путь | Назначение |
| --- | --- |
| `/opt/var/log/xkeen/` | Логи самого XKeen |
| `/opt/var/log/xray/access.log` | Access-лог Xray |
| `/opt/var/log/xray/error.log` | Error-лог Xray |
| `/opt/var/log/xkeen-detached.log` | Лог фоновых запусков (self-detach из `-start/-stop/-restart` без TTY) |

## Runtime-state

| Путь | Назначение |
| --- | --- |
| `/opt/var/run/` | PID-файлы (`xkeen.pid`, `xray.pid`, `mihomo.pid`) |
| `/opt/tmp/xkeen/` | Временная директория XKeen |
| `/opt/tmp/xray/`, `/opt/tmp/mihomo/` | Временные директории ядер |
| `/opt/backups/` | Архивы резервных копий (флаги `-kb`, `-xb`, `-mb`) |
| `/opt/var/spool/cron/crontabs/root` | Cron-задачи (создаются флагом `-ugc`) |

## Хуки в netfilter.d / schedule.d

| Путь | Назначение |
| --- | --- |
| `/opt/etc/ndm/netfilter.d/proxy.sh` | Хук при пересборке правил межсетевого экрана Keenetic — переставляет iptables-правила прокси |
| `/opt/etc/ndm/schedule.d/00-xkeen-hotspot-sync.sh` | Хук на смену клиентов hotspot — обновляет ipset `xkeen_deny_mac` |

## Маркеры

| Файл | Что значит |
| --- | --- |
| `/tmp/toff` | Маркер сессии: отключает таймаут `curl -m 180`. Создаётся флагом `-toff`, очищается trap-ом INT/TERM |
| `/opt/etc/ndm/netfilter.d/aghfix.sh` | Опциональный фикс отображения клиентов в AdGuard Home (флаг `-aghfix`) |
