"""Check embedding order, idempotence, and invalid pages."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "embed-brand.py"


class EmbedBrandTests(unittest.TestCase):
    def test_embed_before_page_styles_and_replace_once(self) -> None:
        with tempfile.TemporaryDirectory(prefix="embed-brand-") as temporary:
            page = Path(temporary) / "page.html"
            page.write_text('<html><head><style>.own{color:red}</style></head><body><p>Hi</p></body></html>', encoding="utf-8")

            def run() -> subprocess.CompletedProcess[str]:
                return subprocess.run([sys.executable, str(SCRIPT), "--path", str(page)], capture_output=True, text=True, check=False)

            result = run()
            self.assertEqual(result.returncode, 0, result.stderr)
            html = page.read_text(encoding="utf-8")
            self.assertLess(html.index("brand begin"), html.index(".own{color:red}"))
            self.assertLess(html.index("theme begin"), html.index("<p>Hi</p>"))
            self.assertIn("data-theme", html)
            self.assertEqual(run().returncode, 0)
            self.assertEqual(page.read_text(encoding="utf-8"), html)

    def test_incomplete_page_fails(self) -> None:
        with tempfile.TemporaryDirectory(prefix="embed-brand-") as temporary:
            page = Path(temporary) / "page.html"
            page.write_text("<p>fragment</p>", encoding="utf-8")
            result = subprocess.run([sys.executable, str(SCRIPT), "--path", str(page)], capture_output=True, text=True, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("no <head>", result.stderr)


if __name__ == "__main__":
    unittest.main()
