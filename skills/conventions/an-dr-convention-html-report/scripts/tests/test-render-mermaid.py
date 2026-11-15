"""Render one diagram in a temporary page; skipped when no Chrome, Edge, or Chromium is installed."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "render-mermaid.py"


def installed_browser() -> str | None:
    for name in ("google-chrome", "chromium", "chromium-browser", "microsoft-edge", "chrome", "msedge"):
        found = shutil.which(name)
        if found:
            return found
    environment = os.environ
    for candidate in (
        f"{environment.get('ProgramFiles', '')}\\Google\\Chrome\\Application\\chrome.exe",
        f"{environment.get('ProgramFiles', '')}\\Microsoft\\Edge\\Application\\msedge.exe",
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    ):
        if candidate and Path(candidate).is_file():
            return candidate
    return None


class RenderMermaidTests(unittest.TestCase):
    def test_renders_a_diagram_in_place(self) -> None:
        if not installed_browser():
            print("render-mermaid test skipped: no browser installed.")
            self.skipTest("no browser installed")
        with tempfile.TemporaryDirectory(prefix="test-render-mermaid-") as temporary:
            page = Path(temporary) / "page.html"
            page.write_text(
                '<html><head></head><body><pre class="mermaid">flowchart TB\n'
                '  A["Start"] --&gt; B["End"]</pre></body></html>',
                encoding="utf-8",
            )
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--path", str(page)],
                capture_output=True,
                text=True,
                encoding="utf-8",
                env={**os.environ, "PYTHONIOENCODING": "utf-8"},
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            rendered = page.read_text(encoding="utf-8")
            self.assertIn("<svg", rendered)
            self.assertNotIn('<pre class="mermaid">', rendered)

    def test_missing_browser_fails_clearly(self) -> None:
        with tempfile.TemporaryDirectory(prefix="test-render-mermaid-") as temporary:
            page = Path(temporary) / "page.html"
            original = '<html><head></head><body><pre class="mermaid">flowchart TB\n  A --&gt; B</pre></body></html>'
            page.write_text(original, encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "-Path", str(page), "-Browser", str(Path(temporary) / "missing.exe")],
                capture_output=True,
                text=True,
                encoding="utf-8",
                env={**os.environ, "PYTHONIOENCODING": "utf-8"},
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Browser not found at", result.stderr)
            self.assertEqual(page.read_text(encoding="utf-8"), original)


if __name__ == "__main__":
    unittest.main()
