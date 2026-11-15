"""Run this skill's validators against the containing skill repository."""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[5]
SCRIPTS = Path(__file__).resolve().parents[1]


class RepositoryValidatorsTests(unittest.TestCase):
    def test_current_repository(self) -> None:
        if not (REPOSITORY / "skills/README.md").is_file():
            self.skipTest("Not in the source skill repository")
        commands = (
            ("check-registration.py", ["--root", str(REPOSITORY), "--fail-on-cycle", "--require-tests"]),
            ("check-skills.py", ["--root", str(REPOSITORY)]),
            ("check-skills-ref.py", ["--root", str(REPOSITORY)]),
        )
        for script, arguments in commands:
            with self.subTest(script=script):
                result = subprocess.run(
                    [sys.executable, str(SCRIPTS / script), *arguments],
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
