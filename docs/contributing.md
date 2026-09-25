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
| `local var` | Разрешено на целевом BusyBox ash (shellcheck SC3043 — ожидаемый шум для POSIX sh) |
| `(( … ))` арифметика | `$(( … ))` или `expr` |
| `read -p` | Разрешено на целевом BusyBox ash (shellcheck SC3045 — ожидаемый шум для POSIX sh) |

**Примечание:** SC3037, SC3043 и SC3045 в выводе `shellcheck` по `echo` с флагами, `local` и `read -p` — ожидаемый шум при анализе POSIX sh. Это не баги и не повод переписывать существующий код.

В `$(( … ))` пользовательское числовое значение с ведущим нулём (`"08"`) ash разбирает как восьмеричное и падает с `arithmetic syntax error`. Префикс `10#` для этого использовать **нельзя**: поддержка `base#num` в BusyBox ash зависит от версии и опции сборки `FEATURE_SH_MATH_BASE`, поэтому на ash роутера её может не быть, а `$(( 10#08 ))` там фатален — ash завершает скрипт. Срезать ведущие нули строковой подстановкой, как в `wait_for_ready()` (`scripts/_xkeen/02_install/07_install_register/04_register_init.sh`):

```sh
val=${start_delay:-60}
val=${val#"${val%%[!0]*}"}   # "008" → "8"
val=${val:-0}                # "000" → "" → 0
_max=$(( val * 2 ))
```

Проверка перед PR (`-s sh` обязателен — без него модули без shebang shellcheck разбирает как bash (SC2148 на каждом таком файле) и пропускает проблемы, специфичные для `sh`; `**` в целевом `sh` не рекурсивен, поэтому обход — через `find`):

```sh
shellcheck -s sh scripts/xkeen
find scripts/_xkeen -name '*.sh' -exec shellcheck -s sh {} +
```

## Пути и URL — только из переменных

Все пути и URL определены в [`scripts/_xkeen/01_info/01_info_variable.sh`](../scripts/_xkeen/01_info/01_info_variable.sh). **Не хардкодить ни одного `/opt/...` пути и ни одного `https://github.com/...` URL** в других файлах. Если нужен новый путь — добавить переменную в `01_info_variable.sh`.

## Добавление модуля

1. Определить, к какой фазе относится: `01_info/`, `02_install/`, `03_delete/`, `04_tools/`, `05_tests/`. Если новый раздел внутри `02_install/` (например, поддиректория `09_install_X/`) — создать каталог и поместить туда `00_<phase>_import.sh`.
2. Создать файл `NN_<purpose>.sh` в нужном каталоге (нумерация — следующая свободная).
3. Подключить через `.` в соответствующем `00_*_import.sh` родительского каталога.
4. Если модуль зависит от других — следить за порядком импорта.

## Добавление новой команды

1. Case-ветка в [`scripts/xkeen`](../scripts/xkeen) в большом `while/case` (имеет условие `while [ $# -gt 0 ]`).
2. Если команда из `{-start, -stop, -restart}` или другая, требующая self-detach в фоне — добавить в проверку на строках 43-48 (`detach_eligible=true`).
3. Описание флага — в `help_xkeen()` функции [`scripts/_xkeen/about.sh`](../scripts/_xkeen/about.sh) под подходящим разделом.
4. Если команда деструктивная — обязательно интерактивное подтверждение перед действием. Не делать «тихие» деструктивные операции.

## Лимиты файловых дескрипторов

Значения в стартовом скрипте: `arm64_fd=40000`, `other_fd=10000`. Не править наугад — увеличение влечёт расход RAM, уменьшение — обрывы соединений на пиках. См. также соответствующий раздел в [`wiki/Configuration.md`](../wiki/Configuration.md).

## Self-detach

Блок в [`scripts/xkeen:43-70`](../scripts/xkeen) — критичный для cron-перезапусков. Без него родитель убивает дочерний процесс по SIGHUP при обрыве ssh-сессии. Трогать только осознанно.

## Проверка перед PR

1. `shellcheck -s sh scripts/xkeen` и `find scripts/_xkeen -name '*.sh' -exec shellcheck -s sh {} +` — нулевая толерантность к новым warning-ам. Shellcheck-гейта в GitHub Actions нет — прогонять вручную перед PR.
2. Деплой архива на тестовый роутер и прогон сценариев: `xkeen -i`, `-start`, `-stop`, `-restart`, `-uk`, `-diag`.
3. Если правились флаги управления (`-ap`, `-dp`, `-ape`, `-dpe`) или режимы проксирования — отдельно прогнать с обоими ядрами (Xray и Mihomo) и в каждом из режимов TProxy/Hybrid/Redirect.
4. `xkeen -diag` — единственный поддерживаемый канал для отчёта о проблеме.
5. `spec/test_*.sh` гоняются автоматически в CI (`.github/workflows/spec-tests.yaml`) при push в `main` и в PR по путям `scripts/**`, `spec/**`; локально — командой из пункта 6 (тесты обращаются к путям `/repo/...`, поэтому запускаются в контейнере с репозиторием, смонтированным в `/repo`).
6. При правках `strip_json_comments`, `jc_set_path`, `speed_balancer_settings` или логики разбора `xkeen.json` — прогнать `spec/*.sh` тем же способом, что и CI ([`.github/workflows/spec-tests.yaml`](../.github/workflows/spec-tests.yaml)):

   ```sh
   docker run --rm -v "$PWD:/repo:ro" alpine:latest sh -c '
     apk add --no-cache jq curl >/dev/null
     cd /repo
     rc=0
     for t in spec/test_*.sh; do
       sh "$t" || rc=1
     done
     exit "$rc"
   '
   ```

   (для podman — тот же вызов с `podman` вместо `docker`).

## CI-файлы — не трогать руками

- [`.github/workflows/package-folder.yaml`](../.github/workflows/package-folder.yaml) и сам артефакт [`test/xkeen.tar.gz`](../test/xkeen.tar.gz) — генерируются CI. Любые ручные правки будут перезаписаны при следующем push в `main` с изменениями `scripts/**`.
- [`.github/workflows/release.yaml`](../.github/workflows/release.yaml) — менять только если действительно меняется процесс релиза.
- [`.github/workflows/wiki-sync.yaml`](../.github/workflows/wiki-sync.yaml) — синхронизирует [`wiki/`](../wiki) в GitHub Wiki. Менять только при изменении логики синхронизации.
- [`.github/workflows/deploy.yaml`](../.github/workflows/deploy.yaml) — публикует mkdocs-сайт на GitHub Pages. Менять только при изменении процесса сборки/публикации доки.
- [`.github/workflows/faq-sync.yaml`](../.github/workflows/faq-sync.yaml) и [`wiki/FAQ.md`](../wiki/FAQ.md) — `FAQ.md` ежедневно (06:00 UTC) перезаписывается этим workflow из `jameszero.net`. Ручные правки `FAQ.md` будут потеряны при следующем синке.
- [`test/changelog.md`](../test/changelog.md) — история изменений и списки коммитов тестовых сборок, их пишет `package-folder.yaml`. Руками не редактировать.

## Документация

- Корневой `README.md` и `wiki/Configuration.md`, `wiki/Forkinfo.md`, `wiki/Knownissues.md` — пользовательская документация. При фичах, затрагивающих пользователя, — обновлять.
- [`test/README.md`](../test/README.md) — release-notes 2.0.1 Beta. При новой Beta-фиче — добавить запись.
- [`docs/`](.) — техническая документация для контрибьюторов. При структурных изменениях кода — обновлять `architecture.md` / `runtime-paths.md` / `commands.md`.
- [`wiki/`](../wiki) — публичная Wiki для пользователей. Обновления синхронизируются автоматически.

## Каналы и версии

- Ветка `main` → Beta-канал, `test/xkeen.tar.gz`, автоматически после push.
- GitHub Release с подписанным тегом → Stable-канал.
- Версия и канал хранятся в [`scripts/_xkeen/01_info/01_info_variable.sh`](../scripts/_xkeen/01_info/01_info_variable.sh): `xkeen_current_version`, `xkeen_build`.
