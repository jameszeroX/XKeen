#!/usr/bin/env python3
"""Convert the FAQ page from jameszero.net to Markdown and splice it into wiki/FAQ.md.

Usage: faq-html2md.py <page.html> <wiki/FAQ.md>

The conversion is purely mechanical (no rewriting): the content of
div.postContent is converted to Markdown and placed between the
`<!-- faq-sync:begin` and `faq-sync:end -->` marker lines in the wiki file.
Exit code: 0 — success (the file may be unchanged), 1 — error.

Invariants:
- HTML comments are stripped BEFORE conversion: the source hides outdated
  items inside <!-- --> and the Crayon plugin emits per-request
  "[Format Time: ...]" comments that would produce noise diffs.
- Crayon/Urvanov code blocks are replaced with fenced code taken from their
  plain <textarea> copy; the highlighted markup contains randomized element
  ids that change on every page load.
- Two runs over the same HTML must produce byte-identical output.
"""

import re
import sys
from urllib.parse import urljoin

from bs4 import BeautifulSoup, Comment
from markdownify import MarkdownConverter

SOURCE_URL = "https://jameszero.net/faq-xkeen.htm"
BEGIN_MARKER = "<!-- faq-sync:begin"
END_MARKER = "faq-sync:end -->"
GENERATED_NOTE = (
    "Автоматическая копия страницы <" + SOURCE_URL + ">.\n"
    "Не редактировать вручную: блок перезаписывается workflow faq-sync\n"
    "(.github/scripts/faq-html2md.py)."
)


def extract_content(html):
    soup = BeautifulSoup(html, "html.parser")
    content = soup.select_one("div.postContent")
    if content is None:
        raise ValueError("div.postContent not found — page layout changed")

    for tag in content.find_all(["script", "style", "noscript"]):
        tag.decompose()
    for comment in content.find_all(string=lambda s: isinstance(s, Comment)):
        comment.extract()

    for crayon in content.select("div.urvanov-syntax-highlighter-syntax"):
        plain = crayon.select_one("textarea.urvanov-syntax-highlighter-plain")
        if plain is None:
            raise ValueError("crayon block without plain textarea — layout changed")
        pre = soup.new_tag("pre")
        code = soup.new_tag("code")
        code.string = plain.get_text().strip("\n")
        pre.append(code)
        crayon.replace_with(pre)

    # <p><strong><a name="N"></a>N</strong></p> is the question numbering —
    # promote it to a heading so the wiki gets anchors and a readable TOC.
    for p in content.find_all("p"):
        text = p.get_text(strip=True)
        if re.fullmatch(r"\d+", text) and p.find("a", attrs={"name": True}):
            heading = soup.new_tag("h3")
            heading.string = text
            p.replace_with(heading)

    # Relative and scheme-relative URLs would break outside the source site;
    # pure-fragment links stay as-is — they target the `### N` headings above.
    for img in content.find_all("img"):
        if img.get("src"):
            img["src"] = urljoin(SOURCE_URL, img["src"])
    for link in content.find_all("a"):
        href = link.get("href")
        if href and not href.startswith("#"):
            link["href"] = urljoin(SOURCE_URL, href)

    return content


def normalize(markdown):
    lines = [line.rstrip() for line in markdown.split("\n")]
    text = "\n".join(lines)
    text = re.sub(r"\n{3,}", "\n\n", text)
    # The result lives inside an HTML comment in wiki/FAQ.md: a literal
    # "-->" would terminate that comment early.
    text = text.replace("-->", "--\\>")
    return text.strip("\n")


def splice(wiki_text, block):
    begin = wiki_text.find(BEGIN_MARKER)
    end = wiki_text.find(END_MARKER)
    if begin == -1 or end == -1 or end < begin:
        raise ValueError(
            "faq-sync markers not found in wiki file "
            "(expected '%s' … '%s')" % (BEGIN_MARKER, END_MARKER)
        )
    head = wiki_text[: begin + len(BEGIN_MARKER)]
    tail = wiki_text[end:]
    return head + "\n" + GENERATED_NOTE + "\n\n" + block + "\n\n" + tail


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: faq-html2md.py <page.html> <wiki/FAQ.md>")
    html_path, wiki_path = sys.argv[1], sys.argv[2]

    with open(html_path, encoding="utf-8") as f:
        html = f.read()
    content = extract_content(html)

    converter = MarkdownConverter(heading_style="ATX", bullets="-")
    block = normalize(converter.convert_soup(content))
    if not block:
        raise ValueError("conversion produced empty content")

    with open(wiki_path, encoding="utf-8") as f:
        wiki_text = f.read()
    updated = splice(wiki_text, block)

    if updated == wiki_text:
        print("faq-sync: no changes")
        return
    with open(wiki_path, "w", encoding="utf-8") as f:
        f.write(updated)
    print("faq-sync: %s updated" % wiki_path)


if __name__ == "__main__":
    main()
