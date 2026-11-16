"""Check the ported message rules through the pure functions and the command line."""

from __future__ import annotations

import os
import runpy
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check-message.py"
RULES = runpy.run_path(str(CHECKER))
VALID = """fix: comma-separate the install features on win-arm64

- a comma-separated list stays one token
"""


def rules_of(message: str, scopes: tuple[str, ...] = ()) -> list[str]:
    violations = RULES["commit_message_violations"](message, scopes)
    return [violation.rule for violation in violations]


def check(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(CHECKER), *arguments],
        capture_output=True,
        text=True,
        encoding="utf-8",
        env={**os.environ, "PYTHONIOENCODING": "utf-8"},
        check=False,
    )


class CommitMessageTests(unittest.TestCase):
    def test_valid_message_passes(self) -> None:
        self.assertEqual(rules_of(VALID), [])
        errors = RULES["error_count"](RULES["commit_message_violations"](VALID))
        self.assertEqual(errors, 0)

    def test_wrong_type_is_rejected(self) -> None:
        rules = rules_of("feature: add the export")
        self.assertEqual(rules, ["subject.type"])
        violations = RULES["commit_message_violations"]("feature: add the export")
        self.assertIn("Type 'feature' is not one of:", violations[0].detail)

    def test_do_not_merge_subject(self) -> None:
        self.assertEqual(rules_of("DO-NOT-MERGE: record the handover state"), [])
        self.assertIn("subject.do-not-merge", rules_of("DO-NOT-MERGE(workflow): record the state"))
        self.assertIn("subject.type", rules_of("DONT-MERGE: record the state"))

    def test_body_must_be_entry_lines(self) -> None:
        prose = "feat: add the export\n\nThis paragraph explains the change at length."
        self.assertEqual(rules_of(prose), ["body.prose"])
        not_an_entry = "feat: add the export\n\n- a real entry\n* a star is not an entry"
        self.assertIn("body.entry", rules_of(not_an_entry))
        missing_separator = "feat: add the export\n- the blank line is missing"
        self.assertIn("body.separator", rules_of(missing_separator))

    def test_ai_attribution_is_rejected(self) -> None:
        trailer = "feat: add the export\n\n- keep one footer\n\nCo-Authored-By: A Tool <tool@example.com>"
        self.assertIn("message.attribution", rules_of(trailer))
        prose_credit = "feat: add the export\n\n- generated with an AI assistant"
        self.assertIn("message.attribution", rules_of(prose_credit))
        tool_as_subject = "feat(install): link the skills into the Copilot directory\n\n- keep one source"
        self.assertNotIn("message.attribution", rules_of(tool_as_subject))

    def test_declared_scopes_come_from_the_host_agents_md(self) -> None:
        with tempfile.TemporaryDirectory(prefix="check-message-") as temporary:
            root = Path(temporary)
            (root / "AGENTS.md").write_text(
                "## Commit scopes\n\n- install\n- cli\n\n## Something else\n\n- elsewhere\n", encoding="utf-8"
            )
            scopes = RULES["declared_scopes"](root)
            self.assertEqual(scopes, ["install", "cli"])
            self.assertEqual(rules_of("feat(install): link the skills", scopes), [])
            self.assertIn("subject.scope", rules_of("feat(web): link the skills", scopes))

    def test_file_argument_and_exit_codes(self) -> None:
        with tempfile.TemporaryDirectory(prefix="check-message-") as temporary:
            failing = Path(temporary) / "failing.txt"
            failing.write_text("feature: add the export\n", encoding="utf-8")
            result = check(str(failing))
            self.assertEqual(result.returncode, 1)
            self.assertIn("subject.type", result.stdout)
            self.assertIn("The message breaks 1 rule(s).", result.stdout)

            passing = Path(temporary) / "passing.txt"
            passing.write_text(VALID, encoding="utf-8")
            result = check(str(passing))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("The commit message matches the format.", result.stdout)

    def test_message_argument_and_quiet_output(self) -> None:
        loud = check("--message", "feature: add the export")
        self.assertEqual(loud.returncode, 1)
        self.assertIn("Commit message check:", loud.stdout)
        quiet = check("-Message", "feature: add the export", "-Quiet")
        self.assertEqual(quiet.returncode, 1)
        self.assertIn("subject.type", quiet.stdout)
        self.assertNotIn("The message breaks", quiet.stdout)

    def test_missing_file_fails_clearly(self) -> None:
        with tempfile.TemporaryDirectory(prefix="check-message-") as temporary:
            result = check(str(Path(temporary) / "absent.txt"))
            self.assertEqual(result.returncode, 1)
            self.assertIn("does not exist", result.stderr)


if __name__ == "__main__":
    unittest.main()
