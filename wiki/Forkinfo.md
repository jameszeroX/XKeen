## Подробное описание изменений форка по сравнению с оригинальным XKeen

Добавлено:

- Совместимость с прошивкой KeeneticOS 5+
- Поддержка ядра Mihomo и смена ядра проксирования (Xray/Mihomo) параметрами запуска `-xray` и `-mihomo`
- Реализована работа с пользовательскими политиками [подробнее](https://github.com/jameszeroX/XKeen/wiki/Configuration#пользовательские-политики)
- Реализовано проксирование DNS [подробнее](https://github.com/jameszeroX/XKeen/wiki/Configuration#Проксирование-dns) (параметр запуска `-dns`)
- Реализована работа с IPSET и возможность исключать из проксирования IP-подсети России (параметры запуска `-gips`, `-dgips`) [подробнее](https://github.com/jameszeroX/XKeen/wiki/Configuration#описание-работы-ipset-в-xkeen)
- Поддержка [DSCP-меток QoS](https://jameszero.net/4509.htm) (`61` - force proxy через отдельный TProxy inbound/listener, `62` - исключение из проксирования, `63` - проксирование)
- Возможность проксирования трафика Entware (параметр запуска `-pr`) [подробнее](https://github.com/jameszeroX/XKeen/wiki/Configuration#проксирование-трафика-entware)
- Возможность отключить/включить протокол IPv6 в KeeneticOS (параметр запуска `-ipv6`)
- Поддержка внешних файлов `ip_exclude.lst`, `port_proxying.lst` и `port_exclude.lst` в директории `/opt/etc/xkeen/` для указания IP и портов (проксирования/исключения из проксирования)
- При недоступности GitHub API используется резервный источник релизов для XKeen, Xray и Mihomo 
- Возможность загружать компоненты XKeen через [Self-Hosted прокси](https://github.com/jameszeroX/XKeen/wiki/Configuration#self-hosted-прокси-для-загрузки-компонентов) при недоступности GitHub. Пользовательский прокси задаётся в параметре `gh_proxy` конфигурационного файла `xkeen.json`
- Параметры `retries_download` и `retry_delay_download` в `xkeen.json` для настройки числа повторных попыток и паузы между ними при загрузке с GitHub. Применяется к загрузке XKeen, Xray, Mihomo, Yq, GeoSite/GeoIP/GeoIPSET и получению списков релизов через GitHub API/jsDelivr. [Подробнее](https://github.com/jameszeroX/XKeen/wiki/Configuration#повторы-загрузки-с-github)
- Возможность [OffLine установки](https://github.com/jameszeroX/XKeen/wiki/Configuration#offline-установка) (параметр запуска `-io`)
- Возможность отключить резервное копирование XKeen при обновлении (параметр запуска `-cbr`)
- Возможность установки GeoIP базы [zkeenip.dat](https://github.com/jameszeroX/zkeen-ip)
- Обновление [zkeen.dat](https://github.com/jameszeroX/zkeen-domains) и [zkeenip.dat](https://github.com/jameszeroX/zkeen-ip) по расписанию средствами XKeen
- При установке теперь можно выбрать, добавлять ли XKeen в автозагрузку при включении роутера или нет
- При обновлении Xray и Mihomo теперь отображается версия уже установленного в роутере бинарника
- При пропуске установки Xray, его конфигурационные файлы и геобазы так же пропускаются и не устанавливаются
- Mihomo и парсер yaml-файлов Yq устанавливаются и регистрируются в entware, как полноценные ipk-пакеты
- Параметр запуска `-remove` для полной деинсталляции XKeen (ранее деинсталляцию нужно было выполнять покомпонентно)
- Параметры запуска `-ug` (обновление геофайлов), `-ugc` (управление заданием Cron, обновляющим геофайлы), `-dgc` (удаление задания Cron, обновляющего геофайлы)
- Параметр запуска `-um` для обновления/установки ядра Mihomo (поддерживается повышение/понижение версии)
- Параметры запуска `-rrm` (обновить регистрацию Mihomo), `-drm` (удалить регистрацию Mihomo)
- Параметр запуска `-dm` для деинсталляции ядра Mihomo
- Параметр запуска `-g`, позволяющий переустановить (добавить/удалить) геофайлы для Xray
- Параметр запуска `-channel`, позволяющий выбрать канал обновления XKeen между Stable и Dev ветками
- Параметр запуска `-di` для установки времени ожидания инициализации роутера перед началом запуска прокси-клиента
- Параметры запуска `-xtest` и `-mtest` для проверки конфигураций Xray и Mihomo на ошибки
- Параметр запуска `-toff` для отключения таймаута загрузок при замедлении GitHub. Пример использования: `xkeen -i -toff`
- Параметры запуска `-mb`, `-mbr` для резервного копирования и восстановления конфигурации Mihomo
- Параметр запуска `-fd` для контроля открытых файловых дескрипторов [подробнее](https://github.com/jameszeroX/XKeen/wiki/Configuration#контроль-файловых-дескрипторов)
- Параметр запуска `-extmsg` для вывода расширенной информации при запуске прокси-клиента

Изменено:

- Исправлено добавление портов в исключения (ранее команду `xkeen -ape` нужно было прерывать по ctrl+c)
- Исправлена совместная работа режима TProxy и socks5 (ранее Xkeen запускался в Mixed режиме, что приводило к неработоспособности прозрачного проксирования)
- Исправлен автозапуск XKeen при старте роутера (ранее XKeen в некоторых случаях не запускался или запускался для всего устройства, а не только для своей политики - [FAQ п.12](https://github.com/jameszeroX/XKeen/wiki/FAQ#12))
- Снято техническое ограничение, позволявшее использовать не более 15 портов проксирования и портов исключенных из проксирования
- Переработана логика загрузки XKeen, Xray, Mihomo и GeoFile из интернета, уменьшающая вероятность их повреждения
- Переработана логика применения правил iptables и ip6tables (ранее XKeen применял все правила, даже при не установленном компоненте IPv6)
- Переработана логика добавления и удаления портов проксирования и исключаемых портов
- При обновлении геофайлов, добавлении/удалении портов проксирования или портов исключений, а также выполнении других настроек, требующих перезапуск XKeen, прокси-клиент теперь перезапускается если был до этого запущен
- При запуске `xkeen -d` без цифрового параметра, теперь отображается информация о текущей задержке автозапуска
- Режим работы Mixed переименован в Hybrid
- При запуске или перезапуске XKeen теперь отображается информация о режиме работы - TProxy, Hybrid (aka Mixed), Redirect, Other
- Не актуальные GeoSite и GeoIP antifilter-community заменены на базы [Re:filter](https://github.com/1andrevich/Re-filter-lists)
- Объединены задачи планировщика по обновлению GeoSite и GeoIP. В связи с этим упразднены параметры запуска `-ugs`, `-ugi`, `-ugsc`, `-ugic`, `-dgsc`, `-dgic`
- Параметр запуска `-ux` для обновления ядра Xray теперь поддерживает повышение/понижение версии
- Корректная деинсталляция xray-core (ранее пакет xray не удалялся при деинсталляции)
- Справка (`xkeen -h`) выровнена по табуляции и повышен контраст текста
- Скрипт запуска S24xray переименован в S05xkeen (для совместимости с IPSET-компонентом)
- Порт 443 в интерфейсе роутера теперь требуется освобождать только для режима TProxy, пользователям Hybrid (Mixed) режима это делать не обязательно
- На роутерах Keenetic Skipper 4G (KN-2910) и Keenetic 4G (KN-1212) после установки теперь не требуется подменять бинарник прокси-клиента, устанавливается сразу совместимый
- Порты проксирования и исключения полностью перенесены в `port_proxying.lst` и `port_exclude.lst`. Параметры `-ap`, `-dp`, `-cp`, `-ape`, `-dpe`, `-cpe` теперь работают только с этими файлам. Переменные `port_donor` и `port_exclude` больше не используются
- DNS-запросы клиентов политик XKeen в журнале AdGuard Home теперь могут отображаться со своими IP-адресами, а не с IP роутера (параметр запуска `-aghfix`)
- XKeen переведён на использование актуальных модулей Netfilter из прошивки
- Задержка автозапуска XKeen теперь не влияет на запуск остальных пакетов, установленных в Entware
- Интерактивные параметры запуска `-auto`, `-fd`, `-dns`, `-pr`, `-ipv6`, `-extmsg`, `-cbk`, `-aghfix` теперь умеют работать в автоматическом режиме (`-dns on`, `-auto off`,... ), а так же поддерживают перезапуск XKeen (`-dns on -restart`), если это необходимо
- Доработан сценарий установки. Корректное определение режима работы XKeen, не зависящее он имен входящих тегов `redirect` и `tproxy` [@UltraFeed](https://github.com/UltraFeed)
- XKeen теперь корректно работает со встроенной политикой Кинетика "Без доступа в интернет", часто используемой при настройке родительского контроля. При создании расписания, доступ в интернет прекращается и восстанавливается согласно заданных интервалов времени [#53](https://github.com/jameszeroX/XKeen/pull/53) - [@kittylabassistant](https://github.com/kittylabassistant)
- Доработки согласно PR [#32](https://github.com/jameszeroX/XKeen/pull/32), [#57](https://github.com/jameszeroX/XKeen/pull/57), [#58](https://github.com/jameszeroX/XKeen/pull/58), [#59](https://github.com/jameszeroX/XKeen/pull/59), [#65](https://github.com/jameszeroX/XKeen/pull/65), [#70](https://github.com/jameszeroX/XKeen/pull/70), [#72](https://github.com/jameszeroX/XKeen/pull/72), [#73](https://github.com/jameszeroX/XKeen/pull/73) - [@kittylabassistant](https://github.com/kittylabassistant)
- Доработки согласно PR [#33](https://github.com/jameszeroX/XKeen/pull/33), [#34](https://github.com/jameszeroX/XKeen/pull/34), [#35](https://github.com/jameszeroX/XKeen/pull/35), [#36](https://github.com/jameszeroX/XKeen/pull/36), [#37](https://github.com/jameszeroX/XKeen/pull/37), [#38](https://github.com/jameszeroX/XKeen/pull/38), [#39](https://github.com/jameszeroX/XKeen/pull/39), [#40](https://github.com/jameszeroX/XKeen/pull/40), [#41](https://github.com/jameszeroX/XKeen/pull/41), [#42](https://github.com/jameszeroX/XKeen/pull/42), [#43](https://github.com/jameszeroX/XKeen/pull/43), [#44](https://github.com/jameszeroX/XKeen/pull/44), [#45](https://github.com/jameszeroX/XKeen/pull/45), [#46](https://github.com/jameszeroX/XKeen/pull/46), [#47](https://github.com/jameszeroX/XKeen/pull/47), [#48](https://github.com/jameszeroX/XKeen/pull/48), [#49](https://github.com/jameszeroX/XKeen/pull/49), [#50](https://github.com/jameszeroX/XKeen/pull/50), [#51](https://github.com/jameszeroX/XKeen/pull/51), [#52](https://github.com/jameszeroX/XKeen/pull/52) - [@oviron](https://github.com/oviron)

Удалено:

- Поддержка внешнего файла `/opt/etc/xkeen_exclude.lst` c IP-адресами и подсетями для исключения из проксирования
- Возможность установки GeoSite Antizapret (база повреждена в репозитории)
- Конфигурационный файл `02_transport.json` (не используется новыми ядрами xray-core)
- Запрос на перезапись и сама перезапись конфигурационных файлов Xray, если они уже существуют на момент установки XKeen
- Создание резервных копий Xray, так как теперь можно интерактивно установить предыдущую версию ядра параметром `-ux`. В связи с этим упразднены параметры запуска `-xb` и `-xbr`
- Логирование процесса установки XKeen в директорию `/opt/var/log/xkeen` (на практике не использовалось)
- Задачи планировщика по автообновлению XKeen/Xray. В связи с этим упразднены параметры запуска `-uac`, `-ukc`, `-uxc`, `-dac`, `-dkc` и `-dxc`
- Неиспользуемые параметры запуска `-x`, `-rk`, `-rx`, `-rc` `-rrk`, `-rrx`, `-rrm`, `-drk`, `-drx`, `-drm`, `-modules`, `-delmodules`
