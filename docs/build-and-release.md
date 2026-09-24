# Сборка и релиз

Локальной сборки нет. Всё делает CI на GitHub Actions. В этом разделе — пять workflow-ов и две схемы каналов обновлений.

## Workflow-ы

### `package-folder.yaml`

[`.github/workflows/package-folder.yaml`](../.github/workflows/package-folder.yaml)

| Параметр | Значение |
| --- | --- |
| Триггер | `push` в `main` с изменениями в `scripts/**`, либо `workflow_dispatch` |
| Результат | `test/xkeen.tar.gz` (Beta-канал, из `scripts/*`) и `test/changelogs/<версия>.md` |
| Подпись | GPG-подписанный автокоммит `[github-actions] automated compiling build <версия>` |

Шаги:

1. Checkout с `fetch-depth: 0` и `ref: ${{ github.ref_name }}` (вершина ветки).
2. Импорт GPG-ключа через `crazy-max/ghaction-import-gpg@v7` с `git_config_global: true`.
3. Вычисление номера сборки; в сборочной копии `scripts_for_build/` подменяются `xkeen_current_version` → `<base>.<N>` и `build_timestamp` → дата `гггг.мм.дд` (MSK). Исходники не меняются: там остаются базовая версия и пустой `build_timestamp`.
4. Упаковка: `cd scripts_for_build && find . -type f -o -type l | sed 's|^\./||' | tar -czf .../xkeen.tar.gz -T -`. На верхнем уровне архива — `xkeen` и `_xkeen/`, без вложенного `scripts/`.
5. Перемещение архива в `test/`.
6. Запись `test/changelogs/<версия>.md`: заголовок, ссылка на исходный коммит, ссылка на compare (если есть новые коммиты) и список коммитов в `scripts/` с прошлой сборки — от старых к новым, без merge-коммитов.
7. Подписанный коммит архива вместе с changelog и push в `HEAD:refs/heads/<ветка>`.

Джоба запускается только из веток (`if: github.ref_type == 'branch'`): ручной запуск с тега завёл бы ветку с именем тега. Запуски идут по очереди (`concurrency`, `cancel-in-progress: false`), checkout берёт вершину ветки, поэтому запуск из очереди видит коммит предыдущей сборки.

#### Номер сборки и changelog

Версия — `<base>.<N>`:

- `base` — значение `xkeen_current_version` в [`scripts/_xkeen/01_info/01_info_variable.sh`](../scripts/_xkeen/01_info/01_info_variable.sh), правится вручную.
- `N` — наибольший номер среди файлов `test/changelogs/<base>.*.md`, когда-либо добавленных в историю git, плюс 1. После смены `base` счёт идёт с 1. Номер сборки, откаченной через `git revert`, повторно не выдаётся.

Changelog перечисляет коммиты в `scripts/` после предыдущей сборки. Предыдущая сборка — последний коммит, чья тема начинается с `[github-actions] automated compiling build` и который менял `test/changelogs/` (если таких нет — `test/xkeen.tar.gz`). Ручные коммиты в `test/changelogs/` точкой отсчёта не становятся. Если предыдущей сборки нет совсем, в changelog пишется «Предыдущая сборка не найдена».

Если новых коммитов в `scripts/` нет, запуск по `push` ничего не коммитит. Ручной запуск (`workflow_dispatch`) коммитит сборку, а в changelog вместо списка пишет «Изменений в `scripts/` нет (пересборка)».

Метка канала берётся из `xkeen_build` в исходниках: если там `Stable`, тестовые сборки тоже помечены `Stable`.

**`test/xkeen.tar.gz` и файлы в `test/changelogs/` пишет CI, руками не редактировать.** Удалённый файл из `test/changelogs/` нумерацию не сбивает: номер считается по истории git.

### `release.yaml`

[`.github/workflows/release.yaml`](../.github/workflows/release.yaml)

| Параметр | Значение |
| --- | --- |
| Триггер | `workflow_dispatch` с входами `version` (string) и `prerelease` (boolean) |
| Результат | `dist/xkeen.tar.gz` + GitHub Release + подписанный GPG-тег |

Шаги:

1. Checkout с `fetch-depth: 0`.
2. Импорт GPG-ключа.
3. Подмена `build_timestamp` на `гггг-мм-дд чч:мм:сс MSK`; номер сборки не добавляется.
4. Проверка синтаксиса: `sh -n` по всем `*.sh` в `scripts_for_release/` и по `scripts_for_release/xkeen`.
5. Упаковка: `find . -type f -o -type l | sed 's|^\./||' | tar -czf "dist/${ARCHIVE_NAME}" -T -` (`ARCHIVE_NAME=xkeen.tar.gz`).
6. Проверка целостности архива: `tar -tzf` по собранному `dist/xkeen.tar.gz`.
7. Удаление существующего тега, создание подписанного `git tag -s "$VERSION"`, push.
8. `gh release create` с архивом `dist/*.tar.gz`. При `prerelease=true` — флаг `--prerelease`.
9. Верификация подписи `git tag -v`.

### `wiki-sync.yaml`

[`.github/workflows/wiki-sync.yaml`](../.github/workflows/wiki-sync.yaml)

| Параметр | Значение |
| --- | --- |
| Триггер | `push` в `main` с изменениями в `wiki/**` или сам workflow, либо `workflow_dispatch` |
| Результат | Содержимое `wiki/` синхронизировано в `<repo>.wiki.git` подписанным коммитом |

Шаги:

1. Checkout главного репо.
2. Импорт GPG-ключа (тот же `crazy-max/ghaction-import-gpg@v7`).
3. Клонирование `<repo>.wiki.git` через `https://x-access-token:${GITHUB_TOKEN}@github.com/<repo>.wiki.git`.
4. `rsync -a --delete --exclude='.git' wiki/ wiki-repo/` — добавление, обновление, удаление.
5. Подписанный коммит `[github-actions] sync wiki from main@<short-sha>` и push в дефолтную ветку Wiki.

Пререкизиты для прода:

- В Settings → Features → Wikis: ✅ enabled.
- В Wiki создана хотя бы одна страница через UI (иначе `<repo>.wiki.git` отдаёт 404).
- В Settings → Actions → General → Workflow permissions: `Read and write permissions`.
- Secret `GPG_PRIVATE_KEY` (passphrase не используется).

### `deploy.yaml`

[`.github/workflows/deploy.yaml`](../.github/workflows/deploy.yaml)

| Параметр | Значение |
| --- | --- |
| Триггер | `push` в `main` с изменениями в `README.md`, `docs/**`, `wiki/**`, `test/README.md`, `mkdocs.yml`, `requirements-docs.txt`, `.github/scripts/stage-docs.sh` или `hooks/**`, либо `workflow_dispatch` |
| Результат | Сайт mkdocs опубликован на GitHub Pages |

Шаги:

1. Checkout.
2. Установка Python и зависимостей из `requirements-docs.txt`.
3. Подготовка источников документации: `.github/scripts/stage-docs.sh`.
4. Сборка `mkdocs build --strict`.
5. `actions/configure-pages@v5`, затем загрузка артефакта `actions/upload-pages-artifact@v3`.
6. Отдельная джоба `deploy`: пауза 60 с (ожидание параллельных деплоев), публикация через `actions/deploy-pages@v4`.

### `faq-sync.yaml`

[`.github/workflows/faq-sync.yaml`](../.github/workflows/faq-sync.yaml)

| Параметр | Значение |
| --- | --- |
| Триггер | Cron `0 6 * * *` (UTC), либо `workflow_dispatch` |
| Результат | `wiki/FAQ.md` синхронизирован с `https://jameszero.net/faq-xkeen.htm`, подписанный автокоммит |

Шаги:

1. Checkout.
2. Скачивание `https://jameszero.net/faq-xkeen.htm` через `curl`.
3. Конвертация HTML в Markdown: `.github/scripts/faq-html2md.py` → `wiki/FAQ.md`.
4. Если в `wiki/FAQ.md` есть diff — импорт GPG-ключа и подписанный `git commit -S` + push в `main`.
5. Программный запуск `gh workflow run wiki-sync.yaml` и `gh workflow run deploy.yaml`: push с `GITHUB_TOKEN` не триггерит push-workflow-ы, поэтому синхронизация Wiki и публикация Pages запускаются явно.

## Каналы обновлений

| Канал | Источник | `xkeen -v` | Триггер |
| --- | --- | --- | --- |
| Stable | GitHub Release с тегом, `xkeen_tar_url` | `XKeen <версия> Stable (гггг-мм-дд чч:мм:сс MSK)` | Прогон `release.yaml` |
| Beta | `test/xkeen.tar.gz` в ветке `main`, `xkeen_dev_url` | `XKeen <версия>.N Beta (гггг.мм.дд)` | Любой merge в `main` с изменениями `scripts/**` |

На роутере переключение каналов — `xkeen -channel`. Текущая версия и канал хранятся в `01_info_variable.sh` (`xkeen_current_version`, `xkeen_build`). После `xkeen -channel` на Stable команда `xkeen -uk` установит Stable-сборку: версия `2.0.1.N` не равна тегу релиза (сравнение строк на равенство).

## Воспроизвести локальную сборку

Без CI, для отладки упаковки:

```sh
cd scripts && find . -type f -o -type l | sed 's|^\./||' | tar -czf /tmp/xkeen.tar.gz -T -
```

Результат идентичен тому, что генерирует `package-folder.yaml` (за исключением подменённого `build_timestamp` и номера сборки). На локальной сборке из исходников (`build_timestamp` пуст) `xkeen -v` показывает `XKeen 2.0.1 Beta` — без номера сборки и даты.
