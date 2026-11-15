"""Inline the dark-cockpit stylesheet into an HTML page so its problem levels render.

Pages mark findings with the ck-* classes and tokens from ../assets/dark-cockpit.css, the HTML
implementation of dark-cockpit. This script places that stylesheet in the page's head, before
the page's own styles, so the page can use the tokens and still override layout.

- Skipped when the page uses no ck-* class, so every page can run it.
- Idempotent: a block between the begin and end markers is replaced, never duplicated.
- One owner: the palette lives only in the asset, so every page shows one fact one way.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


BEGIN = "<!-- an-dr-convention-html-report:cockpit begin -->"
END = "<!-- an-dr-convention-html-report:cockpit end -->"
FINDING_CLASS = re.compile(r"\bck-(critical|high|notice|info|ok|badge|item|quiet)\b", re.IGNORECASE)
INSERTION_POINT = re.compile(
    r"<!-- an-dr-convention-html-repo-style:brand begin -->|<style[\s>]|</head>", re.IGNORECASE
)


def read_text(path: Path) -> str:
    """Read a file as UTF-8, keeping its line endings as written."""
    with open(path, "r", encoding="utf-8-sig", newline="") as stream:
        return stream.read()


def write_text(path: Path, text: str) -> None:
    with open(path, "w", encoding="utf-8", newline="") as stream:
        stream.write(text)


def embed(html: str) -> str | None:
    """Return the page with the stylesheet inlined, or None when it marks no findings."""
    if not FINDING_CLASS.search(html):
        return None
    sheet = Path(__file__).resolve().parent / ".." / "assets" / "dark-cockpit.css"
    if not sheet.is_file():
        raise ValueError(f"Dark-cockpit stylesheet not found at {sheet}.")
    block = f"{BEGIN}\n<style>\n{read_text(sheet).rstrip()}\n</style>\n{END}"
    marked = re.compile(re.escape(BEGIN) + r"[\s\S]*?" + re.escape(END))
    if marked.search(html):
        return marked.sub(lambda _: block, html)
    # Before the page's first stylesheet, so its own rules can refine the shared ones.
    match = INSERTION_POINT.search(html)
    if not match:
        raise ValueError("HTML input has no <head>; write the page as a complete HTML document first.")
    return html[: match.start()] + block + "\n" + html[match.start() :]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("page", nargs="?", type=Path, metavar="path", help="the page to embed into, in place")
    parser.add_argument("--path", "-Path", type=Path, help="the same page, named")
    parser.add_argument("--html", "-Html", default=None, help="markup returned embedded, without writing a file")
    args = parser.parse_args()
    if args.page is not None:
        if args.path is not None:
            parser.error("name the page once, as an argument or with --path")
        args.path = args.page
    if (args.path is None) == (args.html is None):
        parser.error("pass a page path or --html markup, not both")

    page = None
    try:
        if args.path is None:
            html = args.html
        else:
            page = args.path.resolve(strict=True)
            html = read_text(page)
        result = embed(html)
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    if result is None:
        print(html if page is None else f"{page} marks no findings; the dark-cockpit stylesheet was not embedded.")
        return 0
    if page is None:
        print(result)
        return 0
    try:
        write_text(page, result)
    except OSError as error:
        print(error, file=sys.stderr)
        return 1
    print(f"Embedded the dark-cockpit stylesheet into {page}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
