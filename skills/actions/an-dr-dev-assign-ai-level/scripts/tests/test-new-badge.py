"""Check badge output and invalid arguments through the public script."""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "new-badge.py"


class BadgeTests(unittest.TestCase):
    def run_badge(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([sys.executable, str(SCRIPT), *arguments], capture_output=True, text=True, check=False)

    def test_standard_and_compact_badges(self) -> None:
        standard = self.run_badge("--level", "3")
        self.assertEqual(standard.returncode, 0, standard.stderr)
        self.assertIn("[![AI Level 3](https://ai-level.dev/badge/standard/3.svg)](https://ai-level.dev/level-3)", standard.stdout)
        self.assertIn('<a href="https://ai-level.dev/level-3">', standard.stdout)
        compact = self.run_badge("--level", "0", "--style", "compact")
        self.assertEqual(compact.returncode, 0, compact.stderr)
        self.assertIn("/badge/compact/0.svg", compact.stdout)

    def test_invalid_levels_fail(self) -> None:
        for level in ("-1", "5"):
            with self.subTest(level=level):
                result = self.run_badge("--level", level)
                self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
