"""Override page.edit_url from front-matter meta.

В XKeen все страницы сайта стейджатся из канонических источников
(README.md, wiki/*, docs/*) в site_src/ при сборке. По умолчанию
"Edit on GitHub" указывает на путь в site_src/, которого нет в репо.

stage-docs.sh инжектит во front-matter каждой страницы ключ edit_url
с правильным путём к canonical-источнику; этот hook применяет его.
"""

def on_page_context(context, page, config, nav):
    meta = getattr(page, "meta", None) or {}
    if "edit_url" in meta:
        page.edit_url = meta["edit_url"]
    return context
