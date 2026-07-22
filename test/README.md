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
- Сокращено окно отсутствия правил netfilter при пересборке файрвола NDM (renew DHCP) - трафик больше не уходит в обход прокси на 1–1.5 секунды [#98](https://github.com/jameszeroX/XKeen/pull/98) - [@dmiales](https://github.com/dmiales)
- Сгенерированные блобы правил netfilter теперь кэшируются между запусками хука - это дополнительно сокращает окно, в котором трафик идёт мимо прокси после пересборки файрвола NDM [#102](https://github.com/jameszeroX/XKeen/pull/102) - [@dmiales](https://github.com/dmiales)
- Параллельные запуски netfilter.d-хука теперь сериализуются через lock-файл, что устраняет гонку при одновременной пересборке нескольких таблиц iptables [#101](https://github.com/jameszeroX/XKeen/pull/101) - [@dmiales](https://github.com/dmiales)
- Применение правил iptables в netfilter-хуке теперь логирует и повторяет неудачный iptables-restore вместо игнорирования ошибки [#99](https://github.com/jameszeroX/XKeen/pull/99) - [@dmiales](https://github.com/dmiales)
- Для mihomo теперь автоматически выставляется GOMEMLIMIT (половина RAM устройства), что предотвращает рост потребления памяти и убийство процесса OOM-killer'ом на слабых роутерах [#100](https://github.com/jameszeroX/XKeen/pull/100) - [@dmiales](https://github.com/dmiales)
- Функция curl_with_timeout теперь возвращает код возврата curl, а не awk из форматирования прогресс-бара - сетевые сбои при загрузке больше не маскируются под успех [#104](https://github.com/jameszeroX/XKeen/pull/104) - [@MrRefactoring](https://github.com/MrRefactoring)
- Добавлена опциональная балансировка по [фактической скорости](https://github.com/jameszeroX/XKeen/wiki/Configuration#балансировка-по-фактической-скорости) серверов (xkeen -sb) - вместо штатного выбора Xray по задержке (leastPing) [#105](https://github.com/jameszeroX/XKeen/pull/105) - [@MrRefactoring](https://github.com/MrRefactoring)

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
