"""Embed the shared HTML styles and theme switch into a complete page."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


BRAND_BEGIN = "<!-- an-dr-convention-html-repo-style:brand begin -->"
BRAND_END = "<!-- an-dr-convention-html-repo-style:brand end -->"
THEME_BEGIN = "<!-- an-dr-convention-html-repo-style:theme begin -->"
THEME_END = "<!-- an-dr-convention-html-repo-style:theme end -->"
THEME = '''<button type="button" class="brand-theme" id="brand-theme" title="Switch between automatic, light, and dark themes">Theme: auto</button>
<script>
(function () {
  var root = document.documentElement, key = 'docs-html-report-theme';
  var modes = ['auto', 'light', 'dark'];
  var button = document.getElementById('brand-theme');
  function current() { return root.getAttribute('data-theme') || 'auto'; }
  function apply(mode) {
    if (mode === 'auto') root.removeAttribute('data-theme'); else root.setAttribute('data-theme', mode);
    button.textContent = 'Theme: ' + current();
  }
  var saved = null;
  try { saved = localStorage.getItem(key); } catch (e) {}
  apply(modes.indexOf(saved) >= 0 ? saved : current());
  button.addEventListener('click', function () {
    var next = modes[(modes.indexOf(current()) + 1) % modes.length];
    apply(next);
    try { localStorage.setItem(key, next); } catch (e) {}
  });
  // Paper is always light, and nothing on it may stay folded away.
  var before = null, opened = [];
  window.addEventListener('beforeprint', function () {
    before = current();
    if (before !== 'light') root.setAttribute('data-theme', 'light');
    opened = Array.prototype.slice.call(document.querySelectorAll('details:not([open])'));
    opened.forEach(function (d) { d.open = true; });
  });
  window.addEventListener('afterprint', function () {
    if (before) apply(before);
    opened.forEach(function (d) { d.open = false; });
    before = null; opened = [];
  });
})();
</script>'''


def replace_marked(html: str, begin: str, end: str, block: str) -> str | None:
    pattern = re.compile(re.escape(begin) + r"[\s\S]*?" + re.escape(end))
    if pattern.search(html):
        return pattern.sub(lambda _: block, html)
    return None


def embed(path: Path) -> None:
    page = path.resolve(strict=True)
    assets = Path(__file__).resolve().parent.parent / "assets"
    sheets = []
    for name in ("brand.css", "components.css"):
        sheet = assets / name
        if not sheet.is_file():
            raise ValueError(f"Stylesheet not found at {sheet}.")
        sheets.append(sheet.read_text(encoding="utf-8").rstrip())
    styles = "\n".join(sheets)
    brand = f"{BRAND_BEGIN}\n<style>\n{styles}\n</style>\n{BRAND_END}"
    html = page.read_text(encoding="utf-8-sig")
    replaced = replace_marked(html, BRAND_BEGIN, BRAND_END, brand)
    if replaced is not None:
        html = replaced
    else:
        match = re.search(r"<!-- an-dr-convention-html-report:cockpit begin -->|<style[\s>]|</head>", html, re.IGNORECASE)
        if not match:
            raise ValueError(f"{page} has no <head>; write the page as a complete HTML document first.")
        html = html[: match.start()] + brand + "\n" + html[match.start() :]
    theme = f"{THEME_BEGIN}\n{THEME}\n{THEME_END}"
    replaced = replace_marked(html, THEME_BEGIN, THEME_END, theme)
    if replaced is not None:
        html = replaced
    else:
        body = re.search(r"<body[^>]*>", html, re.IGNORECASE)
        if not body:
            raise ValueError(f"{page} has no <body>; write the page as a complete HTML document first.")
        html = html[: body.end()] + "\n" + theme + html[body.end() :]
    page.write_text(html, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", "-Path", type=Path, required=True)
    args = parser.parse_args()
    try:
        embed(args.path)
        print(f"Embedded the HTML style and theme switch into {args.path.resolve()}.")
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
