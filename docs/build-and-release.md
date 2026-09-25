# Сборка и релиз

Локальной сборки нет. Всё делает CI на GitHub Actions. В этом разделе — пять workflow-ов и две схемы каналов обновлений.

## Workflow-ы

### `package-folder.yaml`

[`.github/workflows/package-folder.yaml`](../.github/workflows/package-folder.yaml)

| Параметр | Значение |
| --- | --- |
| Триггер | `push` в `main` с изменениями в `scripts/**`, либо `workflow_dispatch` |
| Результат | `test/xkeen.tar.gz` (Beta-канал, из `scripts/*`) и `test/changelog.md` |
| Подпись | Два GPG-подписанных автокоммита: `[github-actions] automated compiling build` (архив) и `[github-actions] update changelog` (changelog) |

Шаги:

1. Checkout с `fetch-depth: 0`.
2. Импорт GPG-ключа через `crazy-max/ghaction-import-gpg@v7` с `git_config_global: true`.
3. Копирование `scripts/` в `scripts_for_build/` и подмена `build_timestamp="…"` в `scripts_for_build/_xkeen/01_info/01_info_variable.sh` на текущее MSK-время. Из этого же файла читаются (без изменения) `xkeen_current_version` и `xkeen_build` — только для заголовка в changelog.
4. Упаковка: `cd scripts_for_build && find . -type f -o -type l | sed 's|^\./||' | tar -czf .../xkeen.tar.gz -T -`. На верхнем уровне архива — `xkeen` и `_xkeen/`, без вложенного `scripts/`.
5. Перемещение архива в `test/`, удаление временных файлов (`scripts_for_build/`, `output/`).
6. Определение предыдущей сборки — последний коммит с темой `[github-actions] automated compiling build`, менявший `test/xkeen.tar.gz`, и сбор списка коммитов в `scripts/` с прошлой сборки. Если коммитов нет и запуск триггернут `push` (а не `workflow_dispatch`), шаг завершается без коммита и пуша.
7. Подписанный коммит архива (`[github-actions] automated compiling build`). Его хэш используется для прямой ссылки на скачивание (`.../raw/<хэш>/test/xkeen.tar.gz`), привязанной именно к этой сборке.
8. Формирование новой записи в `test/changelog.md` (добавляется в начало файла, старые записи остаются ниже): заголовок `XKeen <версия> <метка> (время сборки: …)`, ссылка на коммит сборки, ссылка на скачивание архива, ссылка на GitHub compare «Изменения с прошлой сборки» (если предыдущая сборка найдена), список коммитов под заголовком «Коммиты» (или пометка «Предыдущая сборка не найдена» / «Изменений в `scripts/` нет (пересборка)»), разделитель `---` в конце записи. Все заголовки — уровня `######`.
9. Подписанный коммит `test/changelog.md` (`[github-actions] update changelog`) и push обоих коммитов в `main`.

**Файл `test/xkeen.tar.gz` — артефакт CI, руками не редактировать. `test/changelog.md` ведётся автоматически, единым файлом, без ручных правок структуры записей.**

### `release.yaml`

[`.github/workflows/release.yaml`](../.github/workflows/release.yaml)

| Параметр | Значение |
| --- | --- |
| Триггер | `workflow_dispatch` с входами `version` (string) и `prerelease` (boolean) |
| Результат | `dist/xkeen.tar.gz` + GitHub Release + подписанный GPG-тег |

Шаги:

1. Checkout с `fetch-depth: 0`.
2. Импорт GPG-ключа.
3. Подмена `build_timestamp` (как в `package-folder.yaml`).
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

| Канал | Источник | Триггер |
| --- | --- | --- |
| Stable | GitHub Release с тегом, `xkeen_tar_url` | Прогон `release.yaml` |
| Beta | `test/xkeen.tar.gz` в ветке `main`, `xkeen_dev_url` | Любой merge в `main` с изменениями `scripts/**` |

На роутере переключение каналов — `xkeen -channel`. Текущая версия и канал хранятся в `01_info_variable.sh` (`xkeen_current_version`, `xkeen_build`).

## Воспроизвести локальную сборку

Без CI, для отладки упаковки:

```sh
cd scripts && find . -type f -o -type l | sed 's|^\./||' | tar -czf /tmp/xkeen.tar.gz -T -
```

Результат идентичен тому, что генерирует `package-folder.yaml` (за исключением подменённого `build_timestamp`).
