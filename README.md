# XKeen 2.0 Beta

[![CodeFactor](https://www.codefactor.io/repository/github/jameszerox/xkeen/badge)](https://www.codefactor.io/repository/github/jameszerox/xkeen) [![Github All Releases](https://img.shields.io/github/downloads/jameszeroX/XKeen/total.svg)](https://github.com/jameszeroX/XKeen/releases) [![License](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause)

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="./docs/xkeen-light.png">
    <img alt="XKeen" src="./docs/xkeen-dark.png">
  </picture>
</p>

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

---

Данный репозиторий является форком оригинального XKeen с исправлениями, расширенной функциональностью и поддержкой актуальных версий KeeneticOS.

## Ключевые изменения форка

### Добавлено

- поддержка **KeeneticOS 5+**
- управление IPv6
- поддержка ядра **Mihomo**
- быстрое переключение Xray / Mihomo
- контроль [файловых дескрипторов](https://github.com/jameszeroX/XKeen/wiki/Configuration#контроль-файловых-дескрипторов)
- [внешние списки](https://github.com/jameszeroX/XKeen/wiki/Configuration#внешние-списки-портов-и-ip) IP и портов
- [OffLine](https://github.com/jameszeroX/XKeen/wiki/Configuration#offline-установка)‑установка
- [Self-Hosted](https://github.com/jameszeroX/XKeen/wiki/Configuration#self-hosted-прокси-для-загрузки)-прокси для загрузки компонентов
- работа с [пользовательскими политиками](https://github.com/jameszeroX/XKeen/wiki/Configuration#пользовательские-политики)
- возможность [проксирования DNS](https://github.com/jameszeroX/XKeen/wiki/Configuration#Проксирование-dns)
- возможность [работы с IPSET](https://github.com/jameszeroX/XKeen/wiki/Configuration#описание-работы-ipset-в-xkeen)
- поддержка [DSCP-меток QoS](https://jameszero.net/4509.htm)
- возможность ([проксирования трафика Entware](https://github.com/jameszeroX/XKeen/wiki/Configuration#проксирование-трафика-entware))
- Совместимость с родительским контролем и политикой "Без доступа в интернет"

### Исправлено

- автозапуск XKeen
- сняты ограничения на количество используемых портов

### Удалено

- не актуальные и повреждённые геобазы
- неиспользуемые конфигурационные файлы
- устаревшие параметры запуска и задачи планировщика

---

### [Подробное описание изменений](https://github.com/jameszeroX/XKeen/wiki/Forkinfo)

---

### [Порядок установки](https://github.com/jameszeroX/XKeen/wiki/Порядок-установки)

---

## Поддержка проекта

Форк XKeen, как и оригинал, совершено бесплатен и не имеет каких либо ограничений по использованию. Надеюсь, доработки XKeen, многие из которых я сделал по Вашим просьбам, оказались полезны, так же, как и мои сообщения в [телеграм-чате](https://t.me/+8Cvh7oVf6cE0MWRi). Для меня очень важно понимать, что труд и время потрачены не зря. Буду благодарен за любую Вашу поддержку на кофе для развития проекта:

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
- XKeen UI — https://github.com/fan92rus/xkeen-ui
- Генератор Outbound — https://zxc-rv.github.io/XKeen-UI/Outbound_Generator/
- Парсер подписок - https://github.com/tkukushkin/xkeen-subscription-watcher
- Парсер подписок — https://github.com/V2as/SubKeen
- Mihomo Studio — https://github.com/l-ptrol/mihomo_studio
- Конвертер JSON-подписок — https://sngvy.github.io/json-sub-to-outbounds
- Mihomo HWID Subscription Installer — https://github.com/dorian6996/Mihomo-HWID-Subscription

---

## Источники и ссылки

- XKeen — https://github.com/Skrill0/XKeen (оригинальный проект, с которого всё началось)
- Xray-core — https://github.com/XTLS/Xray-core
- Mihomo — https://github.com/MetaCubeX/mihomo
- Yq — https://github.com/mikefarah/yq
- FAQ — https://github.com/jameszeroX/XKeen/wiki/FAQ
- Telegram‑чат — https://t.me/+8Cvh7oVf6cE0MWRi
