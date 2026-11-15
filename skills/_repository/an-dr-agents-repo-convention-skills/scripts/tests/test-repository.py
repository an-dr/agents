"""Check the source skill repository's current names."""

from __future__ import annotations

import runpy
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check-names.py"
ROOT = Path(__file__).resolve().parents[5]


class RepositoryNamesTests(unittest.TestCase):
    def test_current_names(self) -> None:
        if not (ROOT / "skills" / "README.md").is_file():
            self.skipTest("Not in the source skill repository")
        count, problems = runpy.run_path(str(CHECKER))["check"](ROOT)
        self.assertGreater(count, 0)
        self.assertEqual(problems, [])


if __name__ == "__main__":
    unittest.main()
