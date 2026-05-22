#!/bin/sh
# Стейджит документацию из канонических источников в site_src/ для mkdocs.
# Запускается и в CI (deploy.yaml), и локально перед `mkdocs serve`.
# POSIX-sh, идемпотентный.

set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/site_src"
REPO="https://github.com/jameszeroX/XKeen"
REPO_BLOB="$REPO/blob/main"
REPO_EDIT="$REPO/edit/main"

rm -rf "$SRC"
mkdir -p "$SRC/guides" "$SRC/dev"

# .pages для awesome-pages plugin: задают title раздела, порядок и подмешивают «...»
# для автоматического включения остальных файлов.
cat > "$SRC/.pages" <<'EOF'
nav:
  - Главная: index.md
  - FAQ: faq.md
  - Конфигурация: configuration.md
  - Изменения форка:
    - Описание изменений: forkinfo.md
    - Известные проблемы: knownissues.md
  - Команды: commands.md
  - guides
  - dev
EOF

cat > "$SRC/guides/.pages" <<'EOF'
title: Руководства
EOF

cat > "$SRC/dev/.pages" <<'EOF'
title: Для разработчиков
nav:
  - index.md
  - ...
EOF

# inject_fm <target_file> <canonical_source_path_in_repo>
# Добавляет YAML front-matter с edit_url, указывающим на canonical-источник,
# чтобы кнопка "Edit on GitHub" в Material вела на правильный файл, а не в site_src/.
inject_fm() {
    target="$1"
    source_path="$2"
    tmp="$target.tmp"
    {
        echo '---'
        echo "edit_url: $REPO_EDIT/$source_path"
        echo '---'
        echo ''
        cat "$target"
    } > "$tmp"
    mv "$tmp" "$target"
}

# --- Копирование канонических источников + front-matter ---

cp "$ROOT/README.md"          "$SRC/index.md"
inject_fm "$SRC/index.md"          "README.md"

cp "$ROOT/wiki/Configuration.md"   "$SRC/configuration.md"
inject_fm "$SRC/configuration.md"  "wiki/Configuration.md"

cp "$ROOT/wiki/Forkinfo.md"        "$SRC/forkinfo.md"
inject_fm "$SRC/forkinfo.md"       "wiki/Forkinfo.md"

cp "$ROOT/wiki/Knownissues.md"     "$SRC/knownissues.md"
inject_fm "$SRC/knownissues.md"    "wiki/Knownissues.md"

# wiki/*.md → авто-цикл. Исключения:
#   - _*.md                                          — GH Wiki scaffolding (_Sidebar.md, _Footer.md, _Header.md)
#   - Configuration.md / Forkinfo.md / Knownissues.md — стейджатся выше как top-level страницы
#   - .gitignore                                      — через `git check-ignore`
# Спецслучай: FAQ.md → site_src/faq.md (top-level URL /faq/).
# Остальные → site_src/guides/<имя>.md (имя файла сохраняется как есть).
for src in "$ROOT"/wiki/*.md; do
    [ -f "$src" ] || continue
    name=$(basename "$src")
    case "$name" in
        _*) continue ;;
        Configuration.md|Forkinfo.md|Knownissues.md) continue ;;
    esac
    rel="wiki/$name"
    if git -C "$ROOT" check-ignore -q "$rel" 2>/dev/null; then
        continue
    fi
    case "$name" in
        FAQ.md)
            cp "$src" "$SRC/faq.md"
            inject_fm "$SRC/faq.md" "$rel"
            ;;
        *)
            cp "$src" "$SRC/guides/$name"
            inject_fm "$SRC/guides/$name" "$rel"
            ;;
    esac
done

# docs/*.md → авто-цикл. Исключения те же (_*.md, .gitignore — release-notes/ авто-скип).
# Спецслучаи:
#   README.md   → site_src/dev/index.md (раздел «Для разработчиков»)
#   commands.md → site_src/commands.md  (top-level URL /commands/)
# Остальные → site_src/dev/<имя>.md
for src in "$ROOT"/docs/*.md; do
    [ -f "$src" ] || continue
    name=$(basename "$src")
    case "$name" in
        _*) continue ;;
    esac
    rel="docs/$name"
    if git -C "$ROOT" check-ignore -q "$rel" 2>/dev/null; then
        continue
    fi
    case "$name" in
        README.md)
            cp "$src" "$SRC/dev/index.md"
            inject_fm "$SRC/dev/index.md" "$rel"
            ;;
        commands.md)
            cp "$src" "$SRC/commands.md"
            inject_fm "$SRC/commands.md" "$rel"
            ;;
        *)
            cp "$src" "$SRC/dev/$name"
            inject_fm "$SRC/dev/$name" "$rel"
            ;;
    esac
done

cp "$ROOT/test/README.md"           "$SRC/dev/beta-notes.md"
inject_fm "$SRC/dev/beta-notes.md"                   "test/README.md"

# --- Трансформации ссылок ---

# (1) GH-style alerts → Material admonitions (только index.md содержит их)
sed -i \
    -e 's/^> \[!WARNING\]$/!!! warning/' \
    -e 's/^> \[!CAUTION\]$/!!! danger/' \
    -e 's/^> \[!NOTE\]$/!!! note/' \
    -e 's/^> /    /' \
    "$SRC/index.md"

# (2) Абсолютные jameszeroX/* ссылки в README.md и forkinfo.md → site-relative
sed -i \
    -e 's|https://github.com/jameszeroX/XKeen/blob/main/wiki/Configuration\.md|./configuration.md|g' \
    -e 's|https://github.com/jameszeroX/XKeen/blob/main/wiki/Forkinfo\.md|./forkinfo.md|g' \
    "$SRC/index.md" "$SRC/forkinfo.md"

# (3a) Wiki extensionless wikilinks из dev/index.md и faq.md (на уровень выше guides/)
for f in "$SRC/dev/index.md" "$SRC/faq.md"; do
    sed -i \
        -e 's|](FAQ)|](../faq.md)|g' \
        -e 's|](Home)|](../guides/Home.md)|g' \
        -e 's|](DNS-over-VLESS)|](../guides/DNS-over-VLESS.md)|g' \
        -e 's|](Маршрутизация-по-DSCP)|](../guides/Маршрутизация-по-DSCP.md)|g' \
        "$f"
done

# (3b) Wiki extensionless wikilinks из самих guides/*.md (siblings)
for f in "$SRC"/guides/*.md; do
    [ -f "$f" ] || continue
    sed -i \
        -e 's|](FAQ)|](../faq.md)|g' \
        -e 's|](Home)|](Home.md)|g' \
        -e 's|](DNS-over-VLESS)|](DNS-over-VLESS.md)|g' \
        -e 's|](Маршрутизация-по-DSCP)|](Маршрутизация-по-DSCP.md)|g' \
        "$f"
done

# (4) Относительные ссылки docs/* → ../scripts/, ../.github/, ../test/, ../install.sh, ../wiki/
find "$SRC/dev" -type f -name '*.md' -exec sed -i \
    -e "s|\.\./scripts/|$REPO_BLOB/scripts/|g" \
    -e "s|\.\./\.github/|$REPO_BLOB/.github/|g" \
    -e "s|\.\./install\.sh|$REPO_BLOB/install.sh|g" \
    -e "s|\.\./test/xkeen\.tar\.gz|$REPO_BLOB/test/xkeen.tar.gz|g" \
    -e "s|\.\./test/README\.md|beta-notes.md|g" \
    -e "s|\.\./wiki/FAQ\.md|../faq.md|g" \
    -e "s|\.\./wiki/Configuration\.md|../configuration.md|g" \
    -e "s|\.\./wiki/Forkinfo\.md|../forkinfo.md|g" \
    -e "s|\.\./wiki/Knownissues\.md|../knownissues.md|g" \
    -e "s|\.\./wiki/\([^/)]*\)\.md|../guides/\1.md|g" \
    -e "s|\.\./wiki/|$REPO_BLOB/wiki/|g" \
    -e "s|](\.\./wiki)|]($REPO/wiki)|g" \
    -e 's|\.\./README\.md|../index.md|g' \
    {} +

# (5) commands.md (был docs/commands.md, теперь на верхнем уровне site_src/)
#     Все ../scripts ссылки тоже надо переписать на абсолютные
sed -i \
    -e "s|\.\./scripts/|$REPO_BLOB/scripts/|g" \
    -e "s|\.\./install\.sh|$REPO_BLOB/install.sh|g" \
    "$SRC/commands.md"

# (6) dev/index.md (был docs/README.md) — ссылки внутри dev/ остаются как есть,
#     но commands.md теперь на уровень выше: ../commands.md
sed -i 's|](commands.md)|](../commands.md)|g' "$SRC/dev/index.md"

# (7) Чистка INFO-несоответствий якорей в исходниках:
#     - устаревший якорь в forkinfo.md (исходный текст ссылается на несуществующий раздел)
#     - кривой якорь "workflow-wiki-syncyaml" в docs/README.md (заголовок без префикса "Workflow")
#     - "[docs/](.)" в contributing.md → "./index.md" (явная ссылка на dev-index)
sed -i 's|#self-hosted-прокси-для-загрузки-компонентов|#self-hosted-прокси-для-загрузки|g' "$SRC/forkinfo.md"
sed -i 's|#workflow-wiki-syncyaml|#wiki-syncyaml|g' "$SRC/dev/index.md"
sed -i 's|\[`docs/`\](\.)|[`docs/`](./index.md)|g' "$SRC/dev/contributing.md"

echo "Staging complete: $SRC"
