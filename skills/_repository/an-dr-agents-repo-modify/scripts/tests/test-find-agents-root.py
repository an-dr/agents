"""Check explicit clone selection and invalid-path diagnostics."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "find-agents-root.py"
ROOT = Path(__file__).resolve().parents[5]


class FindAgentsRootTests(unittest.TestCase):
    def test_explicit_clone_and_invalid_root(self) -> None:
        valid = subprocess.run([sys.executable, str(SCRIPT), "--path", str(ROOT), "--agents-root", str(ROOT)], capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
        self.assertEqual(valid.returncode, 0, valid.stderr)
        self.assertIn("Resolved agents root:", valid.stdout)
        self.assertIn("| branch |", valid.stdout)
        with tempfile.TemporaryDirectory(prefix="not-agents-") as temporary:
            invalid = subprocess.run([sys.executable, str(SCRIPT), "--agents-root", temporary], capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
            self.assertEqual(invalid.returncode, 1)
            self.assertIn("is not an agents clone", invalid.stdout)


if __name__ == "__main__":
    unittest.main()
