"""Check numbering, paths, section headings, and title rejection."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "adr-new.py"


class AdrCreationTests(unittest.TestCase):
    def test_numbered_records(self) -> None:
        with tempfile.TemporaryDirectory(prefix="adr-new-") as temporary:
            root = Path(temporary)
            subprocess.run(["git", "-C", str(root), "init", "--quiet"], check=True, capture_output=True)

            def create(title: str) -> subprocess.CompletedProcess[str]:
                return subprocess.run([sys.executable, str(SCRIPT), "--title", title], cwd=root, capture_output=True, text=True, check=False)

            self.assertEqual(create("Use a shared folder").returncode, 0)
            self.assertEqual(create("Keep one wire contract").returncode, 0)
            first = root / "docs/adr/ADR-001-use-a-shared-folder.md"
            second = root / "docs/adr/ADR-002-keep-one-wire-contract.md"
            self.assertTrue(first.is_file())
            self.assertTrue(second.is_file())
            self.assertEqual(len(list((root / "docs").rglob("*.*"))), 2)
            text = first.read_text(encoding="utf-8")
            for heading in ("# ADR-001: Use a shared folder", "## Problem", "## Decision", "## Rationale", "## Rejected alternatives"):
                self.assertIn(heading, text)
            self.assertNotEqual(create(" ").returncode, 0)


if __name__ == "__main__":
    unittest.main()
