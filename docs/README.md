# Документация XKeen

Этот каталог содержит техническую документацию для разработчиков и контрибьюторов. Если вы пользователь и просто хотите установить XKeen — начните с корневого [`README.md`](../README.md) и [`Configuration.md`](../wiki/Configuration.md).

## Содержание

| Документ | О чём |
| --- | --- |
| [architecture.md](architecture.md) | Точка входа, фазы импорта модулей, режимы проксирования, SSoT-переменные |
| [build-and-release.md](build-and-release.md) | GitHub Actions: пакет в Beta-канал, релиз, синхронизация Wiki. Каналы обновлений |
| [runtime-paths.md](runtime-paths.md) | Раскладка файлов и каталогов на роутере (`/opt/...`) |
| [commands.md](commands.md) | Справочник флагов `xkeen` |
| [contributing.md](contributing.md) | Правила правки кода, ограничения POSIX-`sh`, рабочий цикл проверки |

## Связанные документы

- [`README.md`](../README.md) — обзор и установка для пользователей (в корне репозитория).
- [`wiki/Configuration.md`](../wiki/Configuration.md) — внешние списки портов/IP, fd-контроль, Self-Hosted прокси, OffLine-установка.
- [`wiki/Forkinfo.md`](../wiki/Forkinfo.md) — отличия форка от оригинала Skrill0/XKeen.
- [`wiki/Knownissues.md`](../wiki/Knownissues.md) — известные ограничения. Читать перед триажом багов.
- [`test/README.md`](../test/README.md) — release-notes 2.0 Beta, новые параметры и инварианты.

## Wiki

Исходники GitHub Wiki лежат в [`../wiki/`](../wiki) и автоматически синхронизируются в `<repo>.wiki.git` через workflow `.github/workflows/wiki-sync.yaml`. См. [build-and-release.md](build-and-release.md#workflow-wiki-syncyaml).
