# Правила правки

## Язык — POSIX `sh`

Целевая среда — Entware на BusyBox `ash`. **Никаких bash-измов:**

| Запрещено | Использовать вместо |
| --- | --- |
| `[[ … ]]` | `[ … ]` (POSIX `test`) |
| `${var,,}`, `${var^^}` | `echo "$var" \| tr 'A-Z' 'a-z'` |
| Массивы (`arr=(a b c)`, `${arr[i]}`) | Позиционные параметры, IFS-split строки |
| `<<<` (here-string) | `echo "…" \| cmd` или `<< EOF` |
| `function name()` | `name()` |
| `local var` | Не использовать — `local` не POSIX |
| `(( … ))` арифметика | `$(( … ))` или `expr` |
| `read -p` | `printf '...'; read var` |

Проверка перед PR:

```sh
shellcheck scripts/xkeen scripts/_xkeen/**/*.sh
```

## Пути и URL — только из переменных

Все пути и URL определены в [`scripts/_xkeen/01_info/01_info_variable.sh`](../scripts/_xkeen/01_info/01_info_variable.sh). **Не хардкодить ни одного `/opt/...` пути и ни одного `https://github.com/...` URL** в других файлах. Если нужен новый путь — добавить переменную в `01_info_variable.sh`.

## Добавление модуля

1. Определить, к какой фазе относится: `01_info/`, `02_install/`, `03_delete/`, `04_tools/`, `05_tests/`. Если новый раздел внутри `02_install/` (например, поддиректория `09_install_X/`) — создать каталог и поместить туда `00_<phase>_import.sh`.
2. Создать файл `NN_<purpose>.sh` в нужном каталоге (нумерация — следующая свободная).
3. Подключить через `.` в соответствующем `00_*_import.sh` родительского каталога.
4. Если модуль зависит от других — следить за порядком импорта.

## Добавление новой команды

1. Case-ветка в [`scripts/xkeen`](../scripts/xkeen) в большом `while/case` (начинается со строки 119).
2. Если команда из `{-start, -stop, -restart}` или другая, требующая self-detach в фоне — добавить в проверку на строках 43-48 (`detach_eligible=true`).
3. Описание флага — в `help_xkeen()` функции [`scripts/_xkeen/about.sh`](../scripts/_xkeen/about.sh) под подходящим разделом.
4. Если команда деструктивная — обязательно интерактивное подтверждение перед действием. Не делать «тихие» деструктивные операции.

## Лимиты файловых дескрипторов

Значения в стартовом скрипте: `arm64_fd=40000`, `other_fd=10000`. Не править наугад — увеличение влечёт расход RAM, уменьшение — обрывы соединений на пиках. См. также соответствующий раздел в [`configuration.md`](../configuration.md).

## Self-detach

Блок в [`scripts/xkeen:43-70`](../scripts/xkeen) — критичный для cron-перезапусков. Без него родитель убивает дочерний процесс по SIGHUP при обрыве ssh-сессии. Трогать только осознанно.

## Проверка перед PR

1. `shellcheck scripts/xkeen scripts/_xkeen/**/*.sh` — нулевая толерантность к новым warning-ам.
2. Деплой архива на тестовый роутер и прогон сценариев: `xkeen -i`, `-start`, `-stop`, `-restart`, `-uk`, `-diag`.
3. Если правились флаги управления (`-ap`, `-dp`, `-ape`, `-dpe`) или режимы проксирования — отдельно прогнать с обоими ядрами (Xray и Mihomo) и в каждом из режимов TProxy/Hybrid/Redirect.
4. `xkeen -diag` — единственный поддерживаемый канал для отчёта о проблеме.

## CI-файлы — не трогать руками

- [`.github/workflows/package-folder.yaml`](../.github/workflows/package-folder.yaml) и сам артефакт [`test/xkeen.tar.gz`](../test/xkeen.tar.gz) — генерируются CI. Любые ручные правки будут перезаписаны при следующем push в `main` с изменениями `scripts/**`.
- [`.github/workflows/release.yaml`](../.github/workflows/release.yaml) — менять только если действительно меняется процесс релиза.
- [`.github/workflows/wiki-sync.yaml`](../.github/workflows/wiki-sync.yaml) — синхронизирует [`wiki/`](../wiki) в GitHub Wiki. Менять только при изменении логики синхронизации.

## Документация

- Корневые `README.md`, `configuration.md`, `forkinfo.md`, `knownissues.md` — пользовательская документация. При фичах, затрагивающих пользователя, — обновлять.
- [`test/README.md`](../test/README.md) — release-notes 2.0 Beta. При новой Beta-фиче — добавить запись.
- [`docs/`](.) — техническая документация для контрибьюторов. При структурных изменениях кода — обновлять `architecture.md` / `runtime-paths.md` / `commands.md`.
- [`wiki/`](../wiki) — публичная Wiki для пользователей. Обновления синхронизируются автоматически.

## Каналы и версии

- Ветка `main` → Beta-канал, `test/xkeen.tar.gz`, автоматически после push.
- GitHub Release с подписанным тегом → Stable-канал.
- Версия и канал хранятся в [`scripts/_xkeen/01_info/01_info_variable.sh`](../scripts/_xkeen/01_info/01_info_variable.sh): `xkeen_current_version`, `xkeen_build`.
