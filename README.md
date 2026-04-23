# XKeen 2.0 Beta

> **XKeen** — утилита для выборочной маршрутизации сетевого трафика через прокси‑движки **Xray** и **Mihomo** на роутерах **Keenetic**/**Netcraze**.  
> Позволяет прозрачно направлять TCP/UDP‑трафик только выбранных клиентов, не затрагивая остальную сеть.

---

## Основные возможности

- Выборочная маршрутизация для клиентов в политике доступа в интернет
- Сохранение прямого выхода в интернет для остальных клиентов
- Маршрутизация без политики для всех клиентов роутера
- Поддержка режимов **TProxy**, **Hybrid**, **Redirect**, **Other** (socks5/http)
- Прозрачное проксирование **TCP** и **UDP**
- Поддержка ядер-проксирования **Xray** и **Mihomo**
- Совместимость с **KeeneticOS 5+**
- Управление через shell и [веб-панели](https://github.com/jameszeroX/XKeen?tab=readme-ov-file#дополнения) сторонних разработчиков

XKeen работает полностью на стороне роутера, не меняет настройки клиентов и не требует установки на них дополнительных программ.

---

## Предупреждения

> [!WARNING]
> Данный материал подготовлен в научно‑технических целях. XKeen предназначен для управления межсетевым экраном роутера Keenetic, защищающим домашнюю сеть. Разработчик не несёт ответственности за иное использование утилиты. Перед применением убедитесь, что ваши действия соответствуют законодательству вашей страны.

> [!CAUTION]
> В некоторых случаях протокол IPv6 создаёт проблемы при проксировании. В KeeneticOS IPv6 нельзя полностью отключить стандартными средствами. В XKeen реализован альтернативный механизм его отключения, который полностью убирает IPv6‑трафик на роутере. Это **экспериментальная функция** и может привести к некорректной работе отдельных сервисов Keenetic. Используйте её только при необходимости.

> [!NOTE]
> Установка XKeen гарантируется на внешние USB‑накопители. Установка во внутреннюю память роутера возможна, но требует опыта пользователя. Проблемы, связанные с установкой во внутреннюю память, не считаются ошибками XKeen.

> [!WARNING]
> В KeeneticOS 5+ доступна функция **DNS-маршрутизации** (Routing → DNS-Based Routes). При включённом перехвате DNS в XKeen (`xkeen -dns on`) DNS-пакеты перехватываются на уровне iptables PREROUTING раньше, чем их видит роутер. Из-за этого DNS-маршруты Keenetic **не будут работать**. Не используйте обе функции одновременно.

---

Данный репозиторий является форком оригинального XKeen с исправлениями, расширенной функциональностью и поддержкой актуальных версий KeeneticOS.

## Ключевые изменения форка

### Исправлено

- автозапуск XKeen
- сняты ограничения на количество используемых портов

### Добавлено

- поддержка **KeeneticOS 5+**
- управление IPv6
- поддержка ядра **Mihomo**
- быстрое переключение Xray / Mihomo
- контроль [файловых дескрипторов](https://github.com/jameszeroX/XKeen/blob/main/configuration.md#контроль-файловых-дескрипторов)
- [внешние списки](https://github.com/jameszeroX/XKeen/blob/main/configuration.md#внешние-списки-портов-и-ip) IP и портов
- [OffLine](https://github.com/jameszeroX/XKeen/blob/main/configuration.md#offline-установка)‑установка
- [Self-Hosted](https://github.com/jameszeroX/XKeen/blob/main/configuration.md#self-hosted-прокси-для-загрузки)-прокси для загрузки компонентов

### Удалено

- не актуальные и повреждённые геобазы
- неиспользуемые конфигурационные файлы
- устаревшие параметры запуска и задачи планировщика

---

### Подробное [описание изменений](https://github.com/jameszeroX/XKeen/blob/main/forkinfo.md)

---

Список параметров запуска XKeen доступен в справке:

```bash
xkeen -h
```

---

## Порядок установки

Требуется роутер **Keenetic**/**Netcraze** с предварительно установленной средой Entware и компонентом `Модули ядра подсистемы Netfilter`

```bash
opkg update && opkg upgrade && opkg install curl tar && cd /tmp
sh -c "$(curl -sSL https://raw.githubusercontent.com/jameszeroX/XKeen/main/install.sh)"
```

---

## Поддержка проекта

Форк XKeen, как и оригинал, совершено бесплатен и не имеет каких либо ограничений по использованию. Надеюсь, доработки XKeen, многие из которых я сделал по Вашим просьбам, оказались полезны, так же, как и мои сообщения в [телеграм-чате](https://t.me/+8Cvh7oVf6cE0MWRi). <https://github.com/jameszeroX/XKeen#%D0%BF%D0%BE%D0%B4%D0%B4%D0%B5%D1%80%D0%B6%D0%BA%D0%B0-%D0%BF%D1%80%D0%BE%D0%B5%D0%BA%D1%82%D0%B0> - поддежите форк от jameszeroX или оригинальный XKeen - <https://github.com/Skrill0/XKeen> . Без них не было бы и этого форка

---

## Дополнения

- XKeen UI — <https://github.com/zxc-rv/XKeen-UI>
- XKeen UI — <https://github.com/umarcheh001/Xkeen-UI>
- XKeen UI — <https://github.com/fan92rus/xkeen-ui>
- Генератор Outbound — <https://zxc-rv.github.io/XKeen-UI/Outbound_Generator/>
- Парсер подписок - <https://github.com/tkukushkin/xkeen-subscription-watcher>
- Парсер подписок — <https://github.com/V2as/SubKeen>
- Mihomo Studio — <https://github.com/l-ptrol/mihomo_studio>
- Конвертер JSON-подписок — <https://sngvy.github.io/json-sub-to-outbounds>
- Mihomo HWID Subscription Installer — <https://github.com/dorian6996/Mihomo-HWID-Subscription>

---

## Источники и ссылки

- Origin XKeen — <https://github.com/Skrill0/XKeen>
- Fork XKeen - <https://github.com/jameszeroX/XKeen>
- Xray-core — <https://github.com/XTLS/Xray-core>
- Mihomo — <https://github.com/MetaCubeX/mihomo>
- Yq — <https://github.com/mikefarah/yq>
- FAQ — <https://jameszero.net/faq-xkeen.htm>
- Telegram‑чат — <https://t.me/+8Cvh7oVf6cE0MWRi>
