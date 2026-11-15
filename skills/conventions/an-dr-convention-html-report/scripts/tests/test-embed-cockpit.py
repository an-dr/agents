"""Exercise the public in-memory interface without mutating repository fixtures."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "embed-cockpit.py"
ASSET = Path(__file__).resolve().parents[2] / "assets" / "dark-cockpit.css"
MARKER = "<!-- an-dr-convention-html-report:cockpit begin -->"
PAGE = (
    '<html><head><style>/* page-owned style */</style></head><body>'
    '<div class="ck-notice">Keep $1 &amp; Unicode: café.</div></body></html>'
)


def invoke(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *arguments],
        capture_output=True,
        text=True,
        encoding="utf-8",
        env={**os.environ, "PYTHONIOENCODING": "utf-8"},
        check=False,
    )


class EmbedCockpitTests(unittest.TestCase):
    def embed(self, markup: str) -> str:
        result = invoke("--html", markup)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.rstrip("\n")

    def test_embeds_the_owned_stylesheet_before_page_styles(self) -> None:
        css = ASSET.read_text(encoding="utf-8-sig").rstrip()
        result = self.embed(PAGE)
        self.assertIn(css, result)
        self.assertLess(result.index(MARKER), result.index("/* page-owned style */"))
        self.assertIn("Keep $1 &amp; Unicode: café.", result)

    def test_embedding_is_idempotent(self) -> None:
        result = self.embed(PAGE)
        again = self.embed(result)
        self.assertEqual(again, result)
        self.assertEqual(result.count(MARKER), 1)

    def test_unmarked_page_is_unchanged(self) -> None:
        plain = "<html><head></head><body>No findings.</body></html>"
        self.assertEqual(self.embed(plain), plain)

    def test_quiet_container_needs_the_stylesheet(self) -> None:
        quiet = self.embed(
            '<html><head></head><body><details class="ck-quiet">Passed checks</details></body></html>'
        )
        self.assertIn(MARKER, quiet)

    def test_missing_head_fails_clearly(self) -> None:
        failure = invoke("-Html", '<body><div class="ck-high">Problem</div></body>')
        self.assertNotEqual(failure.returncode, 0)
        self.assertIn("has no <head>", failure.stderr)

    def test_file_mode_rewrites_the_page_in_place(self) -> None:
        with tempfile.TemporaryDirectory(prefix="embed-cockpit-") as temporary:
            page = Path(temporary) / "page.html"
            page.write_text(PAGE, encoding="utf-8")
            result = invoke("--path", str(page))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(f"Embedded the dark-cockpit stylesheet into {page.resolve()}.", result.stdout)
            embedded = page.read_text(encoding="utf-8")
            self.assertIn(MARKER, embedded)
            self.assertIn("Keep $1 &amp; Unicode: café.", embedded)
            again = invoke("-Path", str(page))
            self.assertEqual(again.returncode, 0, again.stderr)
            self.assertEqual(page.read_text(encoding="utf-8"), embedded)


if __name__ == "__main__":
    unittest.main()
