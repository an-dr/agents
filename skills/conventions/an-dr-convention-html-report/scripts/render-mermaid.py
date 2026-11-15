"""Render a report's Mermaid diagrams to inline SVG, each with a button that copies its source.

A report's diagrams are <pre class="mermaid"> blocks, whichever skill wrote the page.
This script renders every one with the vendored build in ../assets/mermaid.min.js inside
a headless Chrome or Edge, and replaces the block with a figure holding:

- a light and a dark SVG, so the diagram follows data-theme on the root element, else
  the system setting, without any script running in the reader's browser;
- a "Copy Mermaid" button and the source in a hidden <pre>, so a reader can take the
  diagram into an editor or another document.

- Static: the page carries no 2.5 MB renderer, and a host that renders Mermaid itself
  finds no <pre class="mermaid"> left to render twice.
- Idempotent: a rendered figure keeps its source, so a rerun renders it again from that
  source, and the shared style and copy script between the markers is replaced.
- Strict: a diagram that fails to parse stops the script with its number and Mermaid's
  message, and the page is left unchanged.
- Offline: no CDN and no npm; only a locally installed Chromium-based browser.

Pinned version: Mermaid 11.4.1. To update, replace assets/mermaid.min.js and the
version below.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from html import unescape
from pathlib import Path


VERSION = "11.4.1"
BEGIN = "<!-- an-dr-convention-html-report:mermaid begin -->"
END = "<!-- an-dr-convention-html-report:mermaid end -->"
FIGURE_BEGIN = "<!-- an-dr-convention-html-report:diagram begin -->"
FIGURE_END = "<!-- an-dr-convention-html-report:diagram end -->"
# Pages embedded before this skill existed carry the old owner's markers.
LEGACY_OWNER = "dev-change-report"
OWNER = r"(?:an-dr-convention-html-report|" + re.escape(LEGACY_OWNER) + ")"

HARNESS = r"""<!DOCTYPE html>
<html><head><meta charset="utf-8"></head><body>
<div id="result"></div>
<script src="mermaid.min.js"></script>
<script>
(async function () {
  var sources = __SOURCES__;
  // Some diagram types name markers with fixed ids such as "arrowhead". Both theme copies sit
  // on one page, and a reference to the hidden copy's marker draws nothing, so every id is
  // made unique to its SVG.
  function scope(svg, prefix) {
    var ids = [], pattern = /\sid="([^"]+)"/g, found;
    while ((found = pattern.exec(svg))) if (found[1] !== prefix) ids.push(found[1]);
    ids.sort(function (a, b) { return b.length - a.length; });
    ids.forEach(function (id) {
      var escaped = id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      svg = svg.replace(new RegExp('(\\sid="|#)' + escaped + '(?![\\w-])', 'g'), '$1' + prefix + '-' + id);
    });
    return svg;
  }
  var results = [];
  for (var i = 0; i < sources.length; i++) {
    var entry = { light: null, dark: null, error: null };
    for (var pass of [['light', 'default'], ['dark', 'dark']]) {
      try {
        mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: pass[1] });
        var prefix = 'report-diagram-' + (i + 1) + '-' + pass[0];
        entry[pass[0]] = scope((await mermaid.render(prefix, sources[i])).svg, prefix);
      } catch (error) {
        entry.error = String(error && error.message || error);
      }
    }
    results.push(entry);
  }
  // Base64, so the dumped DOM carries the SVG markup without any HTML escaping to undo.
  var json = JSON.stringify(results);
  var bytes = new TextEncoder().encode(json), text = '';
  for (var b = 0; b < bytes.length; b++) text += String.fromCharCode(bytes[b]);
  document.getElementById('result').textContent = 'RESULT:' + btoa(text) + ':END';
})();
</script>
</body></html>"""

SHARED = r"""<!-- an-dr-convention-html-report:mermaid begin -->
<!-- Diagrams rendered to SVG with Mermaid __VERSION__ by the an-dr-convention-html-report skill -->
<style>
.report-diagram { position: relative; margin: 1rem 0; overflow-x: auto; }
.report-diagram-view svg { max-width: 100%; height: auto; }
.report-diagram-dark { display: none; }
:root[data-theme="dark"] .report-diagram-light { display: none; }
:root[data-theme="dark"] .report-diagram-dark { display: block; }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) .report-diagram-light { display: none; }
  :root:not([data-theme="light"]) .report-diagram-dark { display: block; }
}
.report-diagram-copy {
  position: absolute; top: 0.25rem; right: 0.25rem; font: inherit; font-size: 0.8rem;
  padding: 0.15rem 0.5rem; cursor: pointer; color: var(--brand-text, inherit);
  background: var(--brand-background, transparent); border: 1px solid currentColor; border-radius: 4px; opacity: 0.6;
}
.report-diagram-copy:hover, .report-diagram-copy:focus { opacity: 1; }
@media print {
  .report-diagram-copy { display: none; }
  .report-diagram .report-diagram-light { display: block !important; }
  .report-diagram .report-diagram-dark { display: none !important; }
}
</style>
<script>
(function () {
  function fallback(text) {
    var area = document.createElement('textarea');
    area.value = text;
    area.style.position = 'fixed';
    area.style.opacity = '0';
    document.body.appendChild(area);
    area.select();
    var ok = document.execCommand('copy');
    document.body.removeChild(area);
    return ok ? Promise.resolve() : Promise.reject();
  }
  document.querySelectorAll('.report-diagram-copy').forEach(function (button) {
    button.addEventListener('click', function () {
      var text = button.parentNode.querySelector('.mermaid-source').textContent;
      // The clipboard API needs a secure context, which a page opened from disk may not be.
      var copy = navigator.clipboard && window.isSecureContext ? navigator.clipboard.writeText(text) : fallback(text);
      copy.then(function () { button.textContent = 'Copied'; }, function () { button.textContent = 'Copy failed'; })
        .then(function () { setTimeout(function () { button.textContent = 'Copy Mermaid'; }, 1500); });
    });
  });
})();
</script>
<!-- an-dr-convention-html-report:mermaid end -->"""

DIAGRAM = re.compile(
    re.escape(FIGURE_BEGIN)
    + r'[\s\S]*?<pre class="mermaid-source"[^>]*>([\s\S]*?)</pre>[\s\S]*?'
    + re.escape(FIGURE_END)
    + r'|<pre class="mermaid"[^>]*>([\s\S]*?)</pre>'
)
SHARED_ELSEWHERE = re.compile(
    r"\s*<!-- " + OWNER + r":mermaid begin -->[\s\S]*?<!-- " + OWNER + r":mermaid end -->"
)


def read_text(path: Path) -> str:
    """Read a file as UTF-8, keeping its line endings as written."""
    with open(path, "r", encoding="utf-8-sig", newline="") as stream:
        return stream.read()


def write_text(path: Path, text: str) -> None:
    with open(path, "w", encoding="utf-8", newline="") as stream:
        stream.write(text)


def html_encode(text: str) -> str:
    """Encode text the way .NET's WebUtility.HtmlEncode does, for the stored source."""
    escaped = {"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"}
    encoded = []
    for character in text:
        code = ord(character)
        if character in escaped:
            encoded.append(escaped[character])
        elif 160 <= code <= 255 or code > 0xFFFF:
            encoded.append(f"&#{code};")
        else:
            encoded.append(character)
    return "".join(encoded)


def script_json(sources: list[str]) -> str:
    """Serialise the sources for the inline script, with "<" escaped."""
    encoded = json.dumps(sources, ensure_ascii=False, separators=(",", ":"))
    return encoded.replace("<", "\\u003c")


def find_browser(browser: str | None) -> str:
    if browser:
        if not Path(browser).is_file():
            raise ValueError(f"Browser not found at {browser}.")
        return browser
    environment = os.environ
    candidates = (
        f"{environment.get('ProgramFiles', '')}\\Google\\Chrome\\Application\\chrome.exe",
        f"{environment.get('ProgramFiles(x86)', '')}\\Google\\Chrome\\Application\\chrome.exe",
        f"{environment.get('LOCALAPPDATA', '')}\\Google\\Chrome\\Application\\chrome.exe",
        f"{environment.get('ProgramFiles(x86)', '')}\\Microsoft\\Edge\\Application\\msedge.exe",
        f"{environment.get('ProgramFiles', '')}\\Microsoft\\Edge\\Application\\msedge.exe",
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    )
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return candidate
    for name in ("google-chrome", "chromium", "chromium-browser", "microsoft-edge", "chrome", "msedge"):
        found = shutil.which(name)
        if found:
            return found
    raise ValueError("No Chrome, Edge, or Chromium found. Install one, or pass its executable with -Browser.")


def render_sources(sources: list[str], browser: str | None) -> list[dict]:
    library = Path(__file__).resolve().parent / ".." / "assets" / "mermaid.min.js"
    if not library.is_file():
        raise ValueError(f"Mermaid build not found at {library}.")
    work = Path(tempfile.mkdtemp(prefix="render-mermaid-"))
    try:
        shutil.copyfile(library, work / "mermaid.min.js")
        page = work / "render.html"
        write_text(page, HARNESS.replace("__SOURCES__", script_json(sources)))
        arguments = [
            "--headless=new",
            f"--user-data-dir={work / 'profile'}",
            "--allow-file-access-from-files",
            "--virtual-time-budget=60000",
            "--dump-dom",
            page.as_uri(),
        ]
        # Redirected to a file: Chrome's large dump arrives empty through a pipe.
        output = work / "dom.html"
        with open(output, "wb") as dump, open(work / "browser.log", "wb") as log:
            subprocess.run([find_browser(browser), *arguments], stdout=dump, stderr=log, check=False)
        dom = read_text(output) if output.is_file() else ""
        match = re.search(r"RESULT:([A-Za-z0-9+/=]*):END", dom)
        if not match:
            raise ValueError("The browser did not finish rendering the diagrams.")
        decoded = base64.b64decode(match.group(1)).decode("utf-8")
        rendered = json.loads(decoded)
        return rendered if isinstance(rendered, list) else [rendered]
    finally:
        shutil.rmtree(work, ignore_errors=True)


def render(path: Path, browser: str | None) -> str:
    """Write the rendered page and return the line to print."""
    report = path.resolve(strict=True)
    html = SHARED_ELSEWHERE.sub("", read_text(report))
    sources = []
    for match in DIAGRAM.finditer(html):
        raw = match.group(1) if match.group(1) is not None else match.group(2)
        sources.append(unescape(raw or "").strip())
    if not sources:
        write_text(report, html)
        return f"No diagrams in {report}; nothing rendered."

    rendered = render_sources(sources, browser)
    failures = [
        f"diagram {index + 1}: {result.get('error')}"
        for index, result in enumerate(rendered)
        if result.get("error")
    ]
    if failures:
        raise ValueError(
            f"Mermaid could not render {len(failures)} diagram(s); {report} is unchanged.\n"
            + "\n".join(failures)
        )

    index = 0

    def figure(_: re.Match[str]) -> str:
        nonlocal index
        source = html_encode(sources[index])
        result = rendered[index]
        index += 1
        return (
            f'{FIGURE_BEGIN}\n<figure class="report-diagram">\n'
            f'<div class="report-diagram-view report-diagram-light">{result.get("light") or ""}</div>\n'
            f'<div class="report-diagram-view report-diagram-dark">{result.get("dark") or ""}</div>\n'
            f'<button type="button" class="report-diagram-copy">Copy Mermaid</button>\n'
            f'<pre class="mermaid-source" hidden>{source}</pre>\n'
            f"</figure>\n{FIGURE_END}"
        )

    html = DIAGRAM.sub(figure, html)
    shared = SHARED.replace("__VERSION__", VERSION)
    bodies = [match for match in re.finditer(r"</body>", html, re.IGNORECASE)]
    if bodies:
        html = html[: bodies[-1].start()] + shared + "\n" + html[bodies[-1].start() :]
    else:
        html = html.rstrip() + "\n" + shared + "\n"
    write_text(report, html)
    return f"Rendered {len(sources)} diagram(s) in {report} to SVG with Mermaid {VERSION}."


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("page", nargs="?", type=Path, metavar="path", help="the report to render in place")
    parser.add_argument("--path", "-Path", type=Path, help="the same report, named")
    parser.add_argument("--browser", "-Browser", default=None, help="a Chromium-based browser; found automatically when omitted")
    args = parser.parse_args()
    if args.page is not None:
        if args.path is not None:
            parser.error("name the report once, as an argument or with --path")
        args.path = args.page
    if args.path is None:
        parser.error("pass the report path")
    try:
        print(render(args.path, args.browser))
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
