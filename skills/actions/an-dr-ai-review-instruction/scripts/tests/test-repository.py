"""Check current instructions and a broken-link fixture."""

from __future__ import annotations

import runpy
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check-references.py"
ROOT = Path(__file__).resolve().parents[5]


class ReferenceTests(unittest.TestCase):
    def test_repository_and_broken_link(self) -> None:
        check = runpy.run_path(str(CHECKER))["check"]
        if (ROOT / "skills" / "README.md").is_file():
            findings, measured = check(ROOT)
            self.assertEqual(findings, [])
            self.assertGreater(len(measured), 0)
        with tempfile.TemporaryDirectory(prefix="broken-ref-") as temporary:
            root = Path(temporary)
            (root / "AGENTS.md").write_text("See [missing](missing.md).\n", encoding="utf-8")
            findings, _ = check(root)
            self.assertEqual(len(findings), 1)
            self.assertEqual(findings[0][2], "reference.link")


if __name__ == "__main__":
    unittest.main()
