"""Ensure the checked-in README matches declared dependencies."""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "build-dependencies.py"
ROOT = Path(__file__).resolve().parents[5]


class RepositoryGraphTests(unittest.TestCase):
    def test_readme_graph(self) -> None:
        if not (ROOT / "skills" / "README.md").is_file():
            self.skipTest("Not in the source skill repository")
        result = subprocess.run([sys.executable, str(SCRIPT), "--root", str(ROOT), "--markdown", str(ROOT / "README.md"), "--check"], capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
