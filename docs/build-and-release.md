# Сборка и релиз

Локальной сборки нет. Всё делает CI на GitHub Actions. В этом разделе — три workflow-а и две схемы каналов обновлений.

## Workflow-ы

### `package-folder.yaml`

[`.github/workflows/package-folder.yaml`](../.github/workflows/package-folder.yaml)

| Параметр | Значение |
| --- | --- |
| Триггер | `push` в `main` с изменениями в `scripts/**`, либо `workflow_dispatch` |
| Результат | `test/xkeen.tar.gz` — Beta-канал, упакован из `scripts/*` |
| Подпись | GPG-подписанный автокоммит `[github-actions] automated compiling build` |

Шаги:

1. Checkout с `fetch-depth: 0`.
2. Импорт GPG-ключа через `crazy-max/ghaction-import-gpg@v7` с `git_config_global: true`.
3. Подмена `build_timestamp="…"` в `scripts/_xkeen/01_info/01_info_variable.sh` на текущее MSK-время.
4. Упаковка: `cd scripts_for_build && find . -type f -o -type l | sed 's|^\./||' | tar -czf .../xkeen.tar.gz -T -`. На верхнем уровне архива — `xkeen` и `_xkeen/`, без вложенного `scripts/`.
5. Перемещение архива в `test/` и подписанный коммит обратно в `main`.

**Файл `test/xkeen.tar.gz` — артефакт CI, руками не редактировать.**

### `release.yaml`

[`.github/workflows/release.yaml`](../.github/workflows/release.yaml)

| Параметр | Значение |
| --- | --- |
| Триггер | `workflow_dispatch` с входами `version` (string) и `prerelease` (boolean) |
| Результат | `dist/xkeen.tar.gz` + `dist/xkeen.tar` + GitHub Release + подписанный GPG-тег |

Шаги:

1. Checkout с `fetch-depth: 0`.
2. Импорт GPG-ключа.
3. Подмена `build_timestamp` (как в `package-folder.yaml`).
4. Двойная упаковка: `.tar.gz` (для роутеров с `tar`+gzip) и `.tar` (для альтернативных распаковщиков).
5. Удаление существующего тега, создание подписанного `git tag -s "$VERSION"`, push.
6. `gh release create` с обоими архивами. При `prerelease=true` — флаг `--prerelease`.
7. Верификация подписи `git tag -v`.

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
