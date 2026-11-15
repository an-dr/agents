"""Check representative valid and invalid names for each skill type."""

from __future__ import annotations

import runpy
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check-names.py"


class SkillNamesTests(unittest.TestCase):
    def test_name_rules(self) -> None:
        check = runpy.run_path(str(CHECKER))["check"]
        cases = (
            ("actions", "an-dr-dev-implement-code", "action", None),
            ("actions", "an-dr-dev-ship-code", "action", "verb 'ship'"),
            ("actions", "an-dr-dev-repair-code", "action", "verb 'repair'"),
            ("actions", "an-dr-build-build-code", "action", "group 'build'"),
            ("actions", "an-dr-files", "action", "needs a group and a verb"),
            ("actions", "an-dr-dev-fix", "action", None),
            ("actions", "dev-build-code", "action", "name must start"),
            ("concepts", "an-dr-ai-slop", "concept", "a concept must be named"),
            ("conventions", "an-dr-markdown", "convention", "a convention must be named"),
            ("_repository", "an-dr-skills", "convention", "must be named an-dr-agents-"),
            ("_repository", "an-dr-agents-repo-skills", "convention", "must be named an-dr-agents-repo-convention-"),
            ("_repository", "an-dr-agents-repo-ship", "action", "verb 'ship'"),
            ("actions", "an-dr-ai-skill-implement-probe", "action", None),
            ("actions", "an-dr-ai-skill", "action", "needs a group and a verb"),
            ("actions", "an-dr-ai-skill-ship-probe", "action", "verb 'ship'"),
            ("actions", "an-dr-ai-skills-test", "action", "verb 'skills'"),
        )
        with tempfile.TemporaryDirectory(prefix="check-names-") as temporary:
            root = Path(temporary)
            for category, name, kind, expected in cases:
                with self.subTest(name=name):
                    path = root / "skills" / category / name / "SKILL.md"
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(f"---\nname: {name}\nmetadata:\n  an-dr.type: {kind}\n---\n", encoding="utf-8")
                    count, problems = check(root)
                    self.assertEqual(count, 1)
                    self.assertEqual(bool(problems), bool(expected), problems)
                    if expected:
                        self.assertIn(expected, problems[0][1])
                    path.unlink()


if __name__ == "__main__":
    unittest.main()
