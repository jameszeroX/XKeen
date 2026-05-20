#!/bin/sh
# Стейджит документацию из канонических источников в site_src/ для mkdocs.
# Запускается и в CI (deploy.yaml), и локально перед `mkdocs serve`.
# POSIX-sh, идемпотентный.

set -eu

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/site_src"
REPO="https://github.com/kittylabassistant/XKeen"
REPO_BLOB="$REPO/blob/main"
REPO_EDIT="$REPO/edit/main"

rm -rf "$SRC"
mkdir -p "$SRC/guides" "$SRC/dev"

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

cp "$ROOT/configuration.md"   "$SRC/configuration.md"
inject_fm "$SRC/configuration.md"  "configuration.md"

cp "$ROOT/forkinfo.md"        "$SRC/forkinfo.md"
inject_fm "$SRC/forkinfo.md"       "forkinfo.md"

cp "$ROOT/knownissues.md"     "$SRC/knownissues.md"
inject_fm "$SRC/knownissues.md"    "knownissues.md"

cp "$ROOT/wiki/FAQ.md"                          "$SRC/faq.md"
inject_fm "$SRC/faq.md"                              "wiki/FAQ.md"

cp "$ROOT/wiki/DNS-over-VLESS.md"               "$SRC/guides/dns-over-vless.md"
inject_fm "$SRC/guides/dns-over-vless.md"            "wiki/DNS-over-VLESS.md"

cp "$ROOT/wiki/Маршрутизация-по-DSCP.md"        "$SRC/guides/dscp-routing.md"
inject_fm "$SRC/guides/dscp-routing.md"              "wiki/Маршрутизация-по-DSCP.md"

cp "$ROOT/docs/README.md"           "$SRC/dev/index.md"
inject_fm "$SRC/dev/index.md"                        "docs/README.md"

cp "$ROOT/docs/architecture.md"     "$SRC/dev/architecture.md"
inject_fm "$SRC/dev/architecture.md"                 "docs/architecture.md"

cp "$ROOT/docs/build-and-release.md" "$SRC/dev/build-and-release.md"
inject_fm "$SRC/dev/build-and-release.md"            "docs/build-and-release.md"

cp "$ROOT/docs/runtime-paths.md"    "$SRC/dev/runtime-paths.md"
inject_fm "$SRC/dev/runtime-paths.md"                "docs/runtime-paths.md"

cp "$ROOT/docs/commands.md"         "$SRC/commands.md"
inject_fm "$SRC/commands.md"                         "docs/commands.md"

cp "$ROOT/docs/contributing.md"     "$SRC/dev/contributing.md"
inject_fm "$SRC/dev/contributing.md"                 "docs/contributing.md"

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
    -e 's|https://github.com/jameszeroX/XKeen/blob/main/configuration\.md|./configuration.md|g' \
    -e 's|https://github.com/jameszeroX/XKeen/blob/main/forkinfo\.md|./forkinfo.md|g' \
    "$SRC/index.md" "$SRC/forkinfo.md"

# (3) Wiki extensionless wikilinks (Home.md → dev/index.md, FAQ-style)
for f in "$SRC/dev/index.md" "$SRC/faq.md"; do
    sed -i \
        -e 's|](FAQ)|](../faq.md)|g' \
        -e 's|](Home)|](../dev/index.md)|g' \
        -e 's|](DNS-over-VLESS)|](../guides/dns-over-vless.md)|g' \
        -e 's|](Маршрутизация-по-DSCP)|](../guides/dscp-routing.md)|g' \
        "$f"
done

# (4) Относительные ссылки docs/* → ../scripts/, ../.github/, ../test/, ../install.sh, ../wiki/
find "$SRC/dev" -type f -name '*.md' -exec sed -i \
    -e "s|\.\./scripts/|$REPO_BLOB/scripts/|g" \
    -e "s|\.\./\.github/|$REPO_BLOB/.github/|g" \
    -e "s|\.\./install\.sh|$REPO_BLOB/install.sh|g" \
    -e "s|\.\./test/xkeen\.tar\.gz|$REPO_BLOB/test/xkeen.tar.gz|g" \
    -e "s|\.\./test/README\.md|beta-notes.md|g" \
    -e "s|\.\./wiki/Маршрутизация-по-DSCP\.md|../guides/dscp-routing.md|g" \
    -e "s|\.\./wiki/FAQ\.md|../faq.md|g" \
    -e "s|\.\./wiki/DNS-over-VLESS\.md|../guides/dns-over-vless.md|g" \
    -e "s|\.\./wiki/|$REPO_BLOB/wiki/|g" \
    -e "s|](\.\./wiki)|]($REPO/wiki)|g" \
    -e 's|\.\./README\.md|../index.md|g' \
    -e 's|\.\./configuration\.md|../configuration.md|g' \
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
