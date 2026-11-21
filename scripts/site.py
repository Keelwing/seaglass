"""Build the GitHub Pages site (docs/DEVELOPMENT.md) into OUT: the landing page (site/index.html), the docs rendered
from the repository's Markdown with a sidebar and the page's sections, the images and the icon. Links between the
docs point at their pages; links to other files of the repository point at GitHub.

Runs in the tool image, which has Python-Markdown: scripts/site.sh (make site).
Usage: python3 site.py REPO OUT
"""
import html
import json
import os
import re
import shutil
import sys
from pathlib import Path, PurePosixPath

import markdown

REPO = Path(sys.argv[1]).resolve()
OUT = Path(sys.argv[2]).resolve()
SITE = REPO / "site"
GITHUB = "https://github.com/Keelwing/seaglass"
VERSION = (REPO / "VERSION").read_text().strip()
VERSIONS = json.loads((REPO / "patchmanager" / "patch.json").read_text())["compatible"]
COMPATIBLE = ", ".join(VERSIONS[:-1]) + " or " + VERSIONS[-1] if len(VERSIONS) > 1 else VERSIONS[0]
# the versions of the testers' package (patchmanager/versions: "VERSION preview")
PREVIEW = [line.split()[0] for line in (REPO / "patchmanager" / "versions").read_text().splitlines()
           if line.split("#")[0].split()[1:] == ["preview"]]
RELEASE = f"{GITHUB}/releases/download/v{VERSION}"
RPM = f"seaglass-{VERSION}-1.noarch.rpm"
RPM_URL = f"{RELEASE}/{RPM}"
# the developer's Ko-fi page (.github/FUNDING.yml, README.md and the settings' About page link the same)
SUPPORT = "https://ko-fi.com/D31m05z"

# The fonts: self-hosted when site/assets/fonts/ holds them (fonts.css), else from Google Fonts
if (SITE / "assets" / "fonts.css").is_file():
    FONTS = ('<link rel="preload" href="{{root}}assets/fonts/albert-sans-latin-wght-normal.woff2" as="font"'
             ' type="font/woff2" crossorigin>\n  <link rel="stylesheet" href="{{root}}assets/fonts.css">')
else:
    FONTS = ('<link rel="preconnect" href="https://fonts.googleapis.com">\n'
             '  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
             '  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Albert+Sans:wght@200;300;400;500;600'
             '&amp;display=swap">')

# The docs, by sidebar group: (source, page, title); a None title is the source's first heading
SECTIONS = [
    ("Guide", [("README.md", "docs/guide.html", "Install and use"),
               ("CHANGELOG.md", "docs/changelog.html", None)]),
    ("How it works", [(f"docs/{name}.md", f"docs/{name.lower()}.html", None)
                      for name in ("FOLDERS", "GLASS", "SEARCH", "BADGES", "SWITCHER", "WIDGETS", "ANIMATIONS")]),
    ("Development", [("docs/ARCHITECTURE.md", "docs/architecture.html", None),
                     ("docs/DEVELOPMENT.md", "docs/development.html", None)]),
]


def released():
    """The day of this version in the changelog ("## 1.1.0 (2026-11-08)"), as "8 November 2026"."""
    match = re.search(rf"^## {re.escape(VERSION)} \((\d+)-(\d+)-(\d+)\)$", (REPO / "CHANGELOG.md").read_text(), re.M)
    if not match:
        sys.exit(f"CHANGELOG.md has no section of {VERSION} with its day")
    months = ("January February March April May June July August September October November December").split()
    year, month, day = (int(part) for part in match.groups())
    return f"{day} {months[month - 1]} {year}"


def older():
    """A word on the testers' package, while patchmanager/versions lists versions for it."""
    if not PREVIEW:
        return ""
    return (f' Sailfish OS {" and ".join(PREVIEW)} have a <a href="{RELEASE}/seaglass-{VERSION}-0.preview1.noarch.rpm">'
            f"testers' package</a>, which CI checks but no such phone has run yet.")


def fill(template, values):
    """The template's {{key}}s, in one pass (a value's own text is not scanned again)."""
    return re.sub(r"\{\{(\w+)\}\}", lambda m: values[m.group(1)], template)


def root_of(page):
    depth = len(PurePosixPath(page).parts) - 1
    return "../" * depth


def relative(target, page):
    return os.path.relpath(target, str(PurePosixPath(page).parent)).replace(os.sep, "/")


def split_title(text):
    """The first level-one heading as the title, and the text without it (and without the README's corner icon)."""
    text = re.sub(r'^<img src="icons/[^"]*"[^>]*>\n+', "", text)
    # the parts for GitHub only: the README's badges and contents (the site has its own navigation, and loads nothing
    # from other sites)
    text = re.sub(r"<!-- github-only -->.*?<!-- /github-only -->\n*", "", text, flags=re.S)
    # a badge from another site (the CI status in the README's Compatibility table) as a plain link to what it shows
    text = re.sub(r"\[!\[[^\]]*\]\(https://[^)]+\)\]\(([^)]+)\)", r"[status](\1)", text)
    match = re.search(r"^# (.+)\n", text, re.M)
    if not match:
        return None, text
    return match.group(1).strip(), text[:match.start()] + text[match.end():]


def rewrite_links(body, source, page, pages):
    """Links of a doc rendered at `page`: other docs to their pages, images to the site's, the rest to GitHub."""
    source_dir = PurePosixPath(source).parent

    def target(url):
        if re.match(r"^(https?:|mailto:|#|data:)", url):
            return url
        path, _, fragment = url.partition("#")
        fragment = "#" + fragment if fragment else ""
        repo_path = os.path.normpath(str(source_dir / path)).replace(os.sep, "/")
        if repo_path in pages:
            return relative(pages[repo_path], page) + fragment
        if repo_path.startswith("docs/images/"):
            return relative("images/" + repo_path[len("docs/images/"):], page)
        if repo_path == "icons/seaglass.svg":
            return relative("icon.svg", page)
        kind = "tree" if (REPO / repo_path).is_dir() else "blob"
        return f"{GITHUB}/{kind}/main/{repo_path}{fragment}"

    return re.sub(r'(href|src)="([^"]+)"', lambda m: f'{m.group(1)}="{html.escape(target(html.unescape(m.group(2))))}"',
                  body)


def partials(page, docs_current):
    values = {"root": root_of(page), "github": GITHUB, "rpm_url": RPM_URL, "version": VERSION, "support": SUPPORT,
              "docs_current": ' aria-current="page"' if docs_current else ""}
    nav = fill((SITE / "templates" / "nav.html").read_text(encoding="utf-8"), values)
    footer = fill((SITE / "templates" / "footer.html").read_text(encoding="utf-8"), values)
    return {"nav": nav, "footer": footer, "fonts": FONTS.replace("{{root}}", values["root"])}


def docnav(page, titles):
    out = []
    for name, docs in SECTIONS:
        items = [(doc_page, titles[doc_page]) for _, doc_page, _ in docs]
        if name == "Guide":
            items.insert(0, ("docs/index.html", "Overview"))
        out.append(f"<h2>{name}</h2>\n      <ul>")
        for item_page, title in items:
            current = ' aria-current="page"' if item_page == page else ""
            out.append(f'        <li><a href="{relative(item_page, page)}"{current}>{html.escape(title)}</a></li>')
        out.append("      </ul>")
    return "\n".join(out)


def walk(tokens):
    for token in tokens:
        yield token
        yield from walk(token.get("children", []))


def toc(tokens):
    items = [token for token in walk(tokens) if token["level"] == 2]
    if len(items) < 2:
        return ""
    links = "\n".join(f'        <li><a href="#{t["id"]}">{t["name"]}</a></li>' for t in items)
    return f"<h2>On this page</h2>\n      <ul>\n{links}\n      </ul>"


def first_paragraph(text):
    for block in re.split(r"\n\s*\n", text):
        block = block.strip()
        if block and not block.startswith(("#", "<", "|", "-", "```", ">")):
            plain = re.sub(r"[*_`]|\[([^\]]+)\]\([^)]+\)", lambda m: m.group(1) or "", block)
            return " ".join(plain.split())
    return ""


def build():
    if OUT.exists():
        for child in OUT.iterdir():
            shutil.rmtree(child) if child.is_dir() else child.unlink()
    OUT.mkdir(parents=True, exist_ok=True)
    shutil.copytree(SITE / "assets", OUT / "assets")
    shutil.copytree(REPO / "docs" / "images", OUT / "images")
    shutil.copy(REPO / "icons" / "seaglass.svg", OUT / "icon.svg")
    (OUT / ".nojekyll").write_text("")

    docs = [doc for _, section in SECTIONS for doc in section]
    pages = {source: page for source, page, _ in docs}
    texts = {}
    titles = {}
    for source, page, title in docs:
        heading, text = split_title((REPO / source).read_text(encoding="utf-8"))
        texts[source] = (title or heading or PurePosixPath(source).stem, text)
        titles[page] = texts[source][0]

    template = (SITE / "templates" / "doc.html").read_text(encoding="utf-8")
    for source, page, _ in docs:
        title, text = texts[source]
        md = markdown.Markdown(extensions=["tables", "fenced_code", "toc", "sane_lists"])
        body = rewrite_links(md.convert(text), source, page, pages)
        values = {"title": html.escape(title), "description": html.escape(first_paragraph(text)[:180]),
                  "docnav": docnav(page, titles), "content": body, "toc": toc(md.toc_tokens),
                  "source": f'<a href="{GITHUB}/blob/main/{source}">This page on GitHub</a>', "root": root_of(page)}
        values.update(partials(page, True))
        (OUT / page).parent.mkdir(parents=True, exist_ok=True)
        (OUT / page).write_text(fill(template, values), encoding="utf-8")

    # the overview of the docs
    rows = []
    for source, page, _ in docs:
        title, text = texts[source]
        rows.append(f'<li><a href="{relative(page, "docs/index.html")}">{html.escape(title)}</a>'
                    f"<br>{html.escape(first_paragraph(text)[:220])}</li>")
    content = ("<p>How to install and use Seaglass, how each feature works, and how it is built.</p>\n"
               "<ul class=\"doc-list\">\n" + "\n".join(rows) + "\n</ul>")
    values = {"title": "Documentation", "description": "The Seaglass documentation.",
              "docnav": docnav("docs/index.html", titles), "content": content, "toc": "",
              "source": f'<a href="{GITHUB}/tree/main/docs">The docs on GitHub</a>', "root": root_of("docs/index.html")}
    values.update(partials("docs/index.html", True))
    (OUT / "docs" / "index.html").write_text(fill(template, values), encoding="utf-8")

    # the landing page
    values = {"version": VERSION, "compatible": COMPATIBLE, "rpm_url": RPM_URL, "rpm": RPM, "support": SUPPORT,
              "github": GITHUB, "released": released(), "sums_url": f"{RELEASE}/SHA256SUMS",
              "older": older()}
    values.update(partials("index.html", False))
    (OUT / "index.html").write_text(fill((SITE / "index.html").read_text(encoding="utf-8"), values), encoding="utf-8")
    print(f"site: {len(docs) + 2} pages in {OUT}")


def check_links():
    """Every link and image of the site to a file of the site: a broken one fails the build."""
    broken = []
    for page in sorted(OUT.rglob("*.html")):
        text = page.read_text(encoding="utf-8")
        for url in re.findall(r'(?:href|src|srcset)="([^"]+)"', text):
            url = html.unescape(url)
            if re.match(r"^(https?:|mailto:|#|data:)", url):
                continue
            path = url.split("#", 1)[0]
            if path and not (page.parent / path).resolve().is_file():
                broken.append(f"{page.relative_to(OUT)}: {url}")
    if broken:
        sys.exit("broken links:\n  " + "\n  ".join(broken))


build()
check_links()
