"""Check that the browser page embeds shared style using Python alone."""

from __future__ import annotations

import runpy
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1]
STYLE_SKILL = Path(__file__).resolve().parents[4] / "conventions" / "an-dr-convention-html-repo-style"


class StyledTemplateTests(unittest.TestCase):
    def test_shared_style(self) -> None:
        namespace = runpy.run_path(str(SCRIPTS / "ai-ui.py"))
        html = namespace["styled_template"](STYLE_SKILL)
        self.assertIn("an-dr-convention-html-repo-style:brand begin", html)
        self.assertIn("an-dr-convention-html-repo-style:theme begin", html)


if __name__ == "__main__":
    unittest.main()
