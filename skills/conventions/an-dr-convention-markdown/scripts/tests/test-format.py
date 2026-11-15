"""Run regression cases for the formatter and the checker's table alignment rule."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


FORMATTER = Path(__file__).resolve().parents[1] / "format-markdown.py"
CHECKER = Path(__file__).resolve().parents[1] / "check-markdown.py"
CASES = (
    (
        "aligns",
        "| A | Long header |\n| --- | --- |\n| value | x |",
        "| A     | Long header |\n| ----- | ----------- |\n| value | x           |",
    ),
    (
        "markers",
        "| A | B | C |\n| :--- | ---: | :-: |\n| one | two | three |",
        "| A   | B   | C     |\n| :-- | --: | :---: |\n| one | two | three |",
    ),
    ("escaped-pipe", "| A |\n| --- |\n| x\\|y |", "| A    |\n| ---- |\n| x\\|y |"),
    (
        "indented",
        "- item\n\n  | A |\n  | --- |\n  | long |",
        "- item\n\n  | A    |\n  | ---- |\n  | long |",
    ),
    ("fence-kept", "```text\n| A |\n| --- |\n| long |\n```", "```text\n| A |\n| --- |\n| long |\n```"),
    ("comment-kept", "<!--\n| A |\n| --- |\n| long |\n-->", "<!--\n| A |\n| --- |\n| long |\n-->"),
    ("trailing-space", "Prose.   ", "Prose."),
)


def run(script: Path, path: Path) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(script), str(path)], capture_output=True, text=True, check=False)


class MarkdownFormatTests(unittest.TestCase):
    def test_formatting(self) -> None:
        with tempfile.TemporaryDirectory(prefix="an-dr-markdown-format-tests-") as temporary:
            directory = Path(temporary)
            for name, body, expected in CASES:
                with self.subTest(name=name):
                    fixture = directory / f"{name}.md"
                    fixture.write_bytes(f"# Example\n\n{body}\n".encode("utf-8"))
                    run(FORMATTER, fixture)
                    first = fixture.read_bytes().decode("utf-8")
                    run(FORMATTER, fixture)
                    second = fixture.read_bytes().decode("utf-8")
                    check = run(CHECKER, fixture)
                    self.assertEqual(first, f"# Example\n\n{expected}\n", check.stdout + check.stderr)
                    self.assertEqual(second, first)
                    self.assertEqual(check.returncode, 0, check.stdout + check.stderr)

    def test_unaligned_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="an-dr-markdown-format-tests-") as temporary:
            fixture = Path(temporary) / "unaligned.md"
            fixture.write_bytes(b"# Example\n\n| A |\n| --- |\n| long |\n")
            check = run(CHECKER, fixture)
            self.assertEqual(check.returncode, 1, check.stdout + check.stderr)
            self.assertIn("table.align", check.stdout + check.stderr)


if __name__ == "__main__":
    unittest.main()
