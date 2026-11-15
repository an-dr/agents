"""Run the script validator against the containing repository."""

from __future__ import annotations

import runpy
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[5]
CHECKER = Path(__file__).resolve().parents[1] / "check-scripts.py"


class RepositoryScriptsTests(unittest.TestCase):
    def test_current_repository(self) -> None:
        if not (ROOT / "skills" / "README.md").is_file():
            self.skipTest("Not in the source skill repository")
        checker = runpy.run_path(str(CHECKER))["check"]
        count, problems = checker(ROOT)
        self.assertGreater(count, 0)
        self.assertEqual(problems, [])


if __name__ == "__main__":
    unittest.main()
