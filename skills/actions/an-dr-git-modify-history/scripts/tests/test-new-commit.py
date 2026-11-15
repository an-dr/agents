"""Check the commit message the recorder assembles from its arguments."""

from __future__ import annotations

import runpy
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1]
NEW_COMMIT = runpy.run_path(str(SCRIPTS / "new-commit.py"))
GIT_ERROR = NEW_COMMIT["GitError"]
compose = NEW_COMMIT["compose_message"]


class ComposeMessageTests(unittest.TestCase):
    def test_subject_carries_scope_and_breaking_mark(self) -> None:
        message = compose("fix", "ci", "cap cargo features", "BREAKING CHANGE: the flag is gone", True, [])
        self.assertEqual(message, "fix(ci)!: cap cargo features\n\nBREAKING CHANGE: the flag is gone\n")
        self.assertEqual(compose("docs", "", "say less", None, False, []), "docs: say less\n")

    def test_entries_become_body_bullets(self) -> None:
        message = compose("fix", None, "split the value", None, False, ["  one line  ", "", "- already marked"])
        self.assertEqual(message, "fix: split the value\n\n- one line\n- already marked\n")

    def test_footers_follow_one_blank_line(self) -> None:
        message = compose("feat", "api", "add a route", "Refs: #12\r\n\r\n\r\nReviewed-by: me", False, ["a change"])
        self.assertEqual(message, "feat(api): add a route\n\n- a change\n\nRefs: #12\nReviewed-by: me\n")

    def test_breaking_change_requires_its_footer(self) -> None:
        with self.assertRaises(GIT_ERROR):
            compose("feat", None, "drop a flag", "Refs: #12", True, [])
        message = compose("feat", None, "drop a flag", "BREAKING CHANGE: the flag is gone", True, [])
        self.assertTrue(message.endswith("\n\nBREAKING CHANGE: the flag is gone\n"))


if __name__ == "__main__":
    unittest.main()
