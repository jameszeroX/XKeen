# Архитектура XKeen

XKeen — POSIX-shell утилита (`sh`, не `bash`) для роутеров Keenetic/Netcraze под Entware. Кода на компилируемых языках нет. Целевые архитектуры — `arm64-v8a`, `mips32le`, `mips32`. Запускается на роутере; в этом репозитории — только исходники и упаковка.

## Точка входа

[`scripts/xkeen`](../scripts/xkeen) — монолитный POSIX-`sh` диспетчер (~1450 строк). Парсит флаги через большой `while/case` начиная со строки 119. Каждый флаг — самостоятельная команда.

### Скрытие установочного каталога

При первом запуске функция `install_xkeen_rename` ([`scripts/xkeen:7-21`](../scripts/xkeen)) переименовывает `_xkeen/` → `.xkeen/`. **Все runtime-пути в коде ссылаются на `.xkeen`. В репозитории каталог называется `_xkeen` — путать легко.** CI пакует именно `_xkeen`.

### Self-detach

Если процесс запущен без TTY (cron, ssh без `-t`, CGI) и команда из `{-start,-stop,-restart}`, `xkeen` форкается через `start-stop-daemon -b` в новую session/pgid с логом в `/opt/var/log/xkeen-detached.log`. Это защищает от обрыва родительской сессии. См. [`scripts/xkeen:43-70`](../scripts/xkeen). Переменная `XKEEN_FOREGROUND=1` отключает детач для скриптов с синхронной семантикой (`xkeen -start && cleanup`).

## Импорт модулей

Все модули — это `. file.sh`-импортируемые библиотеки функций. Точка сборки — [`scripts/_xkeen/import.sh`](../scripts/_xkeen/import.sh), которая последовательно тянет `00_*_import.sh` каждой фазы:

| Фаза | Каталог | Назначение |
| --- | --- | --- |
| 01 | [`01_info/`](../scripts/_xkeen/01_info) | Переменные (SSoT — `01_info_variable.sh`), детекция CPU, проверка установленных Xray/Mihomo/geofile, версии, консольный вывод, cron-статус |
| 02 | [`02_install/`](../scripts/_xkeen/02_install) | Установка: opkg-пакеты → ядра (Xray, Mihomo) → XKeen → geofile/IPSET → cron → регистрация (`07_install_register/`) → шаблоны конфигов (`08_install_configs/02_configs_dir/`) |
| 03 | [`03_delete/`](../scripts/_xkeen/03_delete) | Точечное удаление компонентов + полная деинсталляция (`-remove`) |
| 04 | [`04_tools/`](../scripts/_xkeen/04_tools) | Сервис: управление портами, модули ядра, диагностика, задержка автозапуска, интерактивный выбор (`05_tools_choice/`), бэкапы (`06_tools_backups/`), загрузчики через GH-proxy fallback (`07_tools_downloaders/`) |
| 05 | [`05_tests/`](../scripts/_xkeen/05_tests) | Runtime-проверки сети, портов, носителя |

## Single Source of Truth: `01_info_variable.sh`

Файл [`scripts/_xkeen/01_info/01_info_variable.sh`](../scripts/_xkeen/01_info/01_info_variable.sh) — единственное место, где определены:

- Версия и канал: `xkeen_current_version`, `xkeen_build`, `build_timestamp` (последнее — подставляется CI).
- Все runtime-каталоги: `xkeen_dir=/opt/sbin/.xkeen`, `xkeen_cfg=/opt/etc/xkeen`, `geo_dir=/opt/etc/xray/dat`, и др.
- Все внешние URL: GitHub API для XKeen/Xray/Mihomo, прямые URL архивов, geofile-репозитории.
- GitHub-прокси для регионов с ограничениями: `gh_proxy1=https://gh-proxy.com`, `gh_proxy2=https://ghfast.top`.

При смене версии или URL правится только этот файл. Релизный workflow перезаписывает в нём только `build_timestamp`.

## GH-proxy fallback

Любая загрузка с GitHub в [`04_tools/07_tools_downloaders/`](../scripts/_xkeen/04_tools/07_tools_downloaders) и в корневом [`install.sh`](../install.sh) идёт по цепочке:

1. Прямой URL (например, `github.com/.../xkeen.tar.gz`).
2. `gh_proxy1` префиксом — `https://gh-proxy.com/<github_url>`.
3. `gh_proxy2` префиксом — `https://ghfast.top/<github_url>`.

С версии 2.0 Beta параметр `gh_proxy` из `/opt/etc/xkeen/xkeen.json` имеет приоритет над встроенными значениями.

Маркер `/tmp/toff` (создаётся при запуске с флагом `-toff`) отключает `curl -m 180` на одну сессию — полезно для медленных каналов.

## Режимы проксирования

В рантайме определяется один из четырёх режимов:

| Режим | Признак |
| --- | --- |
| TProxy | Inbound с `streamSettings.sockopt.tproxy == "tproxy"` (Xray) или `listeners[].type == "tproxy"` (Mihomo) |
| Hybrid | Бывший Mixed — комбинация TProxy + Redirect |
| Redirect | Inbound с `sockopt.tproxy == "redirect"`. Самый быстрый, но без UDP |
| Other | socks5/http inbound |

Определение режима — в [`scripts/_xkeen/02_install/07_install_register/04_register_init.sh`](../scripts/_xkeen/02_install/07_install_register/04_register_init.sh) парсингом конфигов Xray (`tproxy`/`redirect` в `streamSettings.sockopt`) и Mihomo (`tproxy-port`, `listeners[].type == "tproxy"`).

**Имена inbound-тегов больше не влияют на режим — исправление 2.0 Beta.** Ранее теги вроде `tproxy-in`/`redirect-in` использовались как fallback, что приводило к ошибкам при кастомных тегах.

## Beta-функции

Описаны в [`test/README.md`](../test/README.md). Кратко:

- Кастомные политики маршрутизации в `xkeen.json`.
- IPSET `ru-exclude` — исключение российских IP из проксирования на уровне ipset.
- DSCP-метки 62 (исключение) и 63 (проксирование) — маршрутизация по приоритетам QoS-пакетов. См. также wiki-страницу [Маршрутизация по DSCP](../wiki/Маршрутизация-по-DSCP.md).
- Проксирование трафика Entware-пакетов с `routing-mark: 255` (Xray) / `mark: 255` (Mihomo).
