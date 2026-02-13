# XKeen 1.1.3.9

> **XKeen** — утилита для выборочной маршрутизации сетевого трафика через прокси‑движки **Xray** и **Mihomo** на роутерах **Keenetic**/**Netcraze**.  
> Позволяет прозрачно направлять TCP/UDP‑трафик только выбранных клиентов, не затрагивая остальную сеть.

---

## Основные возможности

- Выборочная маршрутизация для клиентов в политике доступа в интернет
- Сохранение прямого выхода в интернет для остальных клиентов
- Маршрутизация без политики для всех клиентов роутера
- Поддержка режимов **TProxy**, **Mixed**, **Redirect**, **Other** (socks5/http)
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

Требуется роутер **Keenetic**/**Netcraze** с предварительно установленной средой Entware

Вариант 1:

```bash
opkg update && opkg upgrade && opkg install curl tar && cd /tmp
url="https://raw.githubusercontent.com/jameszeroX/XKeen/main/install.sh"
curl -OL --connect-timeout 10 -m 60 "$url"
chmod +x install.sh
./install.sh
```

Вариант 2:

```bash
opkg update && opkg upgrade && opkg install curl tar && cd /tmp
url="https://github.com/jameszeroX/XKeen/releases/latest/download/xkeen.tar.gz"
curl -OL --connect-timeout 10 -m 60 "$url"
tar -xvzf xkeen.tar.gz -C /opt/sbin > /dev/null && rm xkeen.tar.gz
xkeen -i
```

---

## Поддержка проекта

Форк XKeen, как и оригинал, совершено бесплатен и не имеет каких либо ограничений по использованию. Надеюсь, доработки XKeen, многие из которых я сделал по Вашим просьбам, оказались полезны, так же, как и мои сообщения в [телеграм-чате](https://t.me/+8Cvh7oVf6cE0MWRi). Для меня очень важно понимать, что труд и время потрачены не зря. Буду благодарен за любую Вашу поддержку на развитие проекта:

- [CloudTips](https://pay.cloudtips.ru/p/7edb30ec)
- [ЮMoney](https://yoomoney.ru/to/41001350776240)
- Карта МИР: `2204 1201 2976 4110`
- USDT, сеть TRC20: `TQhy1LbuGe3Bz7EVrDYn67ZFLDjDBa2VNX`
- USDT, сеть ERC20: `0x6a5DF3b5c67E1f90dF27Ff3bd2a7691Fad234EE2`

<sup>Уточните актуальность крипто-адресов перед переводом</sup>

---

## Дополнения

- XKeen UI — https://github.com/zxc-rv/XKeen-UI
- XKeen UI — https://github.com/umarcheh001/Xkeen-UI
- SubKeen — https://github.com/V2as/SubKeen
- Mihomo Studio — https://github.com/l-ptrol/mihomo_studio
- Конвертер JSON-подписок — https://sngvy.github.io/json-sub-to-outbounds

---

## Источники и ссылки

- Origin XKeen — https://github.com/Skrill0/XKeen
- Xray-core — https://github.com/XTLS/Xray-core
- Mihomo — https://github.com/MetaCubeX/mihomo
- Yq — https://github.com/mikefarah/yq
- FAQ — https://jameszero.net/faq-xkeen.htm
- Telegram‑чат — https://t.me/+8Cvh7oVf6cE0MWRi
