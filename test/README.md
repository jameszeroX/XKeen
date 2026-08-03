# XKeen 2.0.1 Beta

> [!NOTE]
> Это версия из канала разработки. Она регулярно дорабатывается, содержит новейшие функции, возможности и исправления, но может иметь не выявленные ошибки. Если столкнулись с проблемой - обязательно обновитесь командой `xkeen -uk`, возможно ошибка уже известна и исправлена. Если же проблема сохранилась, выполните `xkeen -diag` и покажите диагностический отчёт в телеграм-чате <https://t.me/+8Cvh7oVf6cE0MWRi>, подробно описав возникшую проблему

## Изменения

- Добавлена поддержка ([токенов доступа к RCI](https://github.com/jameszeroX/XKeen/wiki/Конфигурационный-файл)) для совместимости с KeeneticOS 5.2
- Расширен функционал [маршрутизации по DSCP-меткам](https://github.com/jameszeroX/XKeen/wiki/Маршрутизация-по-DSCP). Добавлена метка `61` - принудительное проксирование через отдельный transparent inbound/listener - [@MichaelDavislol](https://github.com/MichaelDavislol), [@zxc-rv](https://github.com/zxc-rv)
- Добавлена политика `xkeen_full`, повторяющая функционал `DSCP 61` для устройств в политике роутера
- Реализована возможность [проксирования через выбранного провайдера](https://github.com/jameszeroX/XKeen/wiki/Configuration#pbr-для-исходящих-подключений-xraymihomo) - [@MichaelDavislol](https://github.com/MichaelDavislol)
- Перед началом установки XKeen выполняется базовая проверка исправности Entware
- Добавлена возможность автообновления пользовательских геофайлов ([настройка](https://github.com/jameszeroX/XKeen/wiki/Конфигурационный-файл))
- Исправлена установка/обновление геофайлов и GeoIPSET ([известные проблемы](https://github.com/jameszeroX/XKeen/wiki/Knownissues))
- Скрыт выбор установки Mihomo Prerelease-Alpha ([известные проблемы](https://github.com/jameszeroX/XKeen/wiki/Knownissues))
- Сокращено окно отсутствия правил netfilter при пересборке файрвола NDM (renew DHCP) - трафик больше не уходит в обход прокси на 1–1.5 секунды; хук дополнительно защищён от гонок при частых renew: сгенерированный файл хука пишется атомарно (не бывает пустым/обрезанным), deny-MAC ipset не затирается пустым набором при сбое RCI, respawn mihomo из хука использует PID-lock (не залипает после OOM) [#98](https://github.com/jameszeroX/XKeen/pull/98), [#116](https://github.com/jameszeroX/XKeen/pull/116) - [@dmiales](https://github.com/dmiales)
- Сгенерированные блобы правил netfilter теперь кэшируются между запусками хука - это дополнительно сокращает окно, в котором трафик идёт мимо прокси после пересборки файрвола NDM [#102](https://github.com/jameszeroX/XKeen/pull/102) - [@dmiales](https://github.com/dmiales)
- Параллельные запуски netfilter.d-хука теперь сериализуются через lock-файл, что устраняет гонку при одновременной пересборке нескольких таблиц iptables; тот же лок распространён на clean_firewall (не сносит цепочки посреди iptables-restore на renew), а emergency_clear берёт общий proxy-mutex, чтобы не сорвать правила посреди обычного start/stop/restart [#101](https://github.com/jameszeroX/XKeen/pull/101), [#117](https://github.com/jameszeroX/XKeen/pull/117) - [@dmiales](https://github.com/dmiales)
- Применение правил iptables в netfilter-хуке теперь логирует и повторяет неудачный iptables-restore вместо игнорирования ошибки [#99](https://github.com/jameszeroX/XKeen/pull/99) - [@dmiales](https://github.com/dmiales)
- Для mihomo теперь автоматически выставляется GOMEMLIMIT (половина RAM устройства, предусмотрена настройка через `xkeen.json`), что предотвращает рост потребления памяти и убийство процесса OOM-killer'ом на слабых роутерах [#100](https://github.com/jameszeroX/XKeen/pull/100), [#114](https://github.com/jameszeroX/XKeen/pull/114) - [@dmiales](https://github.com/dmiales)
- Функция curl_with_timeout теперь возвращает код возврата curl, а не awk из форматирования прогресс-бара - сетевые сбои при загрузке больше не маскируются под успех [#104](https://github.com/jameszeroX/XKeen/pull/104) - [@MrRefactoring](https://github.com/MrRefactoring)
- Добавлена опциональная балансировка по [фактической скорости](https://github.com/jameszeroX/XKeen/wiki/Configuration#балансировка-по-фактической-скорости) серверов (xkeen -sb) - вместо штатного выбора Xray по задержке (leastPing) [#105](https://github.com/jameszeroX/XKeen/pull/105) - [@MrRefactoring](https://github.com/MrRefactoring)
- Распаковка обновления теперь атомарна (временный каталог + подмена), добавлена проверка целостности архива mihomo (gzip -t с откатом) и минимального размера загруженного ядра — прерванное обновление больше не оставляет XKeen в полуустановленном состоянии [#112](https://github.com/jameszeroX/XKeen/pull/112) - [@dmiales](https://github.com/dmiales)
- Хук netfilter.d пропускает пересборку маршрутов/правил при коротких DHCP renew, если WAN IP не изменился, а цепочки целы — меньше лишней работы на каждый renew [#115](https://github.com/jameszeroX/XKeen/pull/115) - [@dmiales](https://github.com/dmiales)
- Рантайм XKeen (локи, state, кэш правил, -toff) перенесён из world-writable /tmp с предсказуемыми именами в /tmp/.xkeen (root:root, 0700); убран eval при загрузке кэша правил, PID пишется в cold_start-лок сразу при создании [#118](https://github.com/jameszeroX/XKeen/pull/118) - [@dmiales](https://github.com/dmiales)
- ~~Релизы XKeen теперь подписываются (.minisig) и проверяются при загрузке;~~ ядра xray/mihomo сверяются по sha256 с апстримом напрямую (не через то же зеркало, что отдало файл); режим .xkeen.verify_downloads (по умолчанию warn, не ломает offline-сценарии); починка определения размера у зеркала через Content-Range; отдельный workspace на каждый вызов вместо общего /tmp/xkeen, чтобы параллельные -ug/-um не пересекались [#119](https://github.com/jameszeroX/XKeen/pull/119) - [@dmiales](https://github.com/dmiales) (Бинарный файл minisign отсутствует в mipsle варианте, выполняется поиск другого аналогичного решения для подписи XKeen)
- Установка (install.sh/install_xkeen) идёт через staging + .old-подмену — обрыв не оставляет полуустановку; xkeen.json и каталог конфига получают права 600/700 (там RCI-токен), дожимаются идемпотентно на -uk; перезапись crontab теперь матчит только полные команды xkeen -ug|-ux|-uk и пишет через tmp+mv — чужие строки в crontab больше не затираются [#120](https://github.com/jameszeroX/XKeen/pull/120) - [@dmiales](https://github.com/dmiales)
- Сбой RCI больше не валит stop/status целиком (жёсткий выход только там, где без политик нельзя стартовать); занятый proxy-mutex у stop/restart теперь либо ретраится, либо явно возвращает ошибку «занято» вместо молчаливого кода 0; proxy_start считает успех только после удачного применения netfilter-хука [#121](https://github.com/jameszeroX/XKeen/pull/121) - [@dmiales](https://github.com/dmiales)
- Добавлен опциональный kill-switch (.xkeen.killswitch.enabled, xkeen -killswitch on|off|status) — при аварии ядра дропает только помеченный политикой трафик вместо прямой утечки в обход прокси; дефолт off, xkeen -stop снимает блокировку полностью. Добавлен кэш последнего успешного policy mark на случай сбоя RCI (вместо отката к «прокси для всех»). На реальном железе матчинг DROP-правила переведён с connmark на packet-mark (fwmark) — connmark не срабатывал после сноса save-mark цепочки [#122](https://github.com/jameszeroX/XKeen/pull/122) - [@dmiales](https://github.com/dmiales)
- Точечное восстановление сета geo_exclude, если он опустел после OOM при живом .lst-файле (включая fast-path «WAN не менялся»); wait_for_ready теперь принимает от RCI и объект, и массив, не гоняя полный таймаут на пустом наборе [#123](https://github.com/jameszeroX/XKeen/pull/123) - [@dmiales](https://github.com/dmiales)

### Порядок установки/обновления

```bash
opkg update && opkg upgrade && opkg install curl tar && cd /tmp
sh -c "$(curl -sSL https://raw.githubusercontent.com/jameszeroX/XKeen/main/install.sh)" -- --beta
```

### Порядок обновления с XKeen 2.0

```bash
xkeen -channel # переключитесь на канал разработки
xkeen -uk  # проверьте и установите обновление
```

Последующие запуски команды `xkeen -uk` в канале разработки каждый раз загружают и обновляют бету XKeen на актуальную версию
