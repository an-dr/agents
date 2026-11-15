"""Run regression cases for comment handling and prose-wrap enforcement."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check-markdown.py"
CASES = (
    ("multiline-comment", "<!--\nhidden text\n-->", 0),
    ("comment-syntax", "\n".join(["<!--", "``` ", "# Hidden heading", "_hidden_", "-->"]), 0),
    ("inline-comment", "Visible <!-- hidden --> prose.", 0),
    ("trailing-comment", "Visible prose. <!-- hidden -->", 0),
    ("multiple-comments", "<!-- first --> <!-- second -->", 0),
    ("comment-in-inline-code", "Use `<!--` to start a comment.\nContinued prose.", 1),
    ("escaped-comment", "Use \\<!-- as literal text.\nContinued prose.", 1),
    ("wrapped-prose", "Visible prose\ncontinued here.", 1),
    ("wrap-before-comment", "Visible prose\ncontinued here.\n<!-- hidden -->", 1),
    ("wrap-after-comment", "<!-- hidden -->\nVisible prose\ncontinued here.", 1),
    ("visible-suffix", "<!-- hidden\n--> Visible prose\ncontinued here.", 1),
    ("comment-in-code", "\n".join(["```html", "<!--", "```", "", "Visible prose", "continued here."]), 1),
)


class MarkdownRegressionTests(unittest.TestCase):
    def test_cases(self) -> None:
        with tempfile.TemporaryDirectory(prefix="an-dr-markdown-tests-") as temporary:
            directory = Path(temporary)
            for name, body, expected in CASES:
                with self.subTest(name=name):
                    fixture = directory / f"{name}.txt"
                    fixture.write_bytes(f"# Example\n\n{body}\n".encode("utf-8"))
                    result = subprocess.run(
                        [sys.executable, str(CHECKER), str(fixture)], capture_output=True, text=True, check=False
                    )
                    output = result.stdout + result.stderr
                    self.assertEqual(result.returncode, expected, output)
                    if expected == 1:
                        self.assertIn("line.wrap", output)


if __name__ == "__main__":
    unittest.main()
