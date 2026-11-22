"""Break a disposable copy of the skills one way at a time and expect a named break."""

from __future__ import annotations

import importlib.util
import shutil
import tempfile
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[5]
CHECKER = Path(__file__).resolve().parents[1] / "check-skills.py"
SPEC = importlib.util.spec_from_file_location("check_skills", CHECKER)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
IGNORED = shutil.ignore_patterns("scripts", "assets", "fixtures", "*.zip")


class SkillChecksTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="check-skills-")
        self.root = Path(self.temporary.name)
        shutil.copytree(REPOSITORY / "skills", self.root / "skills", ignore=IGNORED)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def files(self) -> tuple[list[tuple[str, str]], list[tuple[str, str]]]:
        _, problems, warnings = MODULE.check(self.root)
        return problems, warnings

    def edit(self, path: str, old: str, new: str) -> None:
        file = self.root / path
        text = file.read_text(encoding="utf-8")
        self.assertIn(old, text, f"Fixture text '{old}' not found in {path}.")
        file.write_text(text.replace(old, new), encoding="utf-8")

    def append(self, path: str, text: str) -> None:
        with (self.root / path).open("a", encoding="utf-8") as stream:
            stream.write(text)

    def assert_problem(self, expected: str) -> None:
        problems, _ = self.files()
        self.assertTrue(any(expected in what for _, what in problems), f"Expected problem '{expected}', got {problems}.")

    def assert_warning(self, expected: str) -> None:
        _, warnings = self.files()
        self.assertTrue(any(expected in what for _, what in warnings), f"Expected warning '{expected}', got {warnings}.")

    def test_clean_copy(self) -> None:
        problems, _ = self.files()
        self.assertEqual(problems, [])

    def test_artifact_kinds(self) -> None:
        review = "skills/actions/an-dr-dev-review/SKILL.md"
        for entry, expected in (
            ("Code_Review", "must be one kind in lowercase hyphenated words"),
            ("code-review deslop", "must be one kind in lowercase hyphenated words"),
            ("other", "reserved for one-off outputs"),
            ("code-slop-report", "already declared by"),
        ):
            with self.subTest(entry=entry):
                self.setUp()
                self.edit(review, "an-dr.artifact.kind: code-review", f"an-dr.artifact.kind: {entry}")
                self.assert_problem(expected)
        self.setUp()
        self.edit(review, "an-dr.artifact.pin-latest: true", "an-dr.artifact.pin-latest: yes")
        self.assert_problem("must be true or false")
        self.setUp()
        self.edit(review, "  an-dr.artifact.kind: code-review\n", "")
        self.assert_problem("need an-dr.artifact.kind")
        self.setUp()
        self.edit("skills/actions/an-dr-ai-use-user-interface/SKILL.md", "an-dr.artifact.pin-latest: false", "an-dr.artifact.pin-latest: true")
        self.assert_problem("internal artifact kind keeps no latest copy")

    def test_no_trigger_sentence(self) -> None:
        self.edit("skills/actions/an-dr-dev-debug/SKILL.md", "Use ", "Apply ")
        self.assert_problem("description has no trigger sentence beginning 'Use '")

    def test_concept_title(self) -> None:
        self.edit("skills/concepts/an-dr-concept-single-authority/SKILL.md", "# Concept: single authority", "# Single authority")
        self.assert_problem("must start with 'Concept: '")

    def test_action_title_prefix(self) -> None:
        self.edit("skills/actions/an-dr-dev-debug/SKILL.md", "# Debug", "# Convention: debug")
        self.assert_problem("uses a concept or convention prefix on an action")

    def test_concept_without_violations(self) -> None:
        self.edit("skills/concepts/an-dr-concept-single-authority/SKILL.md", "## Violations", "## Pitfalls")
        self.assert_problem("has no '## Violations' section")

    def test_examples_not_last(self) -> None:
        self.append("skills/conventions/an-dr-convention-commit-message/SKILL.md", "\n## Afterword\n\nNone.\n")
        self.assert_problem("'## Examples' must be the last section")

    def test_over_the_token_budget_warns(self) -> None:
        self.append("skills/actions/an-dr-dev-debug/SKILL.md", "filler " * 1000)
        self.assert_warning("tokens; the budget is 1500, so move branch material into references/")

    def test_command_in_a_concept_warns(self) -> None:
        self.append("skills/concepts/an-dr-concept-single-authority/SKILL.md", "\n```sh\npython run.py\n```\n")
        self.assert_warning("a concept contains a command to run")

    def test_reference_links(self) -> None:
        references = self.root / "skills/actions/an-dr-dev-debug/references"
        references.mkdir()
        (references / "bisect.md").write_text("How to bisect.", encoding="utf-8")
        self.assert_problem("is not linked from SKILL.md, so no agent reads it")
        self.append("skills/actions/an-dr-dev-debug/SKILL.md", "\nTo bisect, read [references/bisect.md](references/bisect.md).\n")
        problems, _ = self.files()
        self.assertEqual(problems, [])
        self.append("skills/actions/an-dr-dev-debug/SKILL.md", "\nFor logs, read [references/logs.md](references/logs.md).\n")
        self.assert_problem("links references/logs.md, which does not exist")

    def test_unknown_key_and_comma_tools(self) -> None:
        self.edit("skills/actions/an-dr-git-modify-history/SKILL.md", "license: MIT", "license: MIT\nallowed-tools: Bash, Read\nuser-invocable: false")
        self.assert_problem("frontmatter key 'user-invocable' is not part of the Agent Skills format")
        self.assert_problem("allowed-tools must be a space-separated string")

    def test_yaml_colon_in_description(self) -> None:
        self.edit("skills/actions/an-dr-git-modify-history/SKILL.md", "description: Change a", "description: Note: change a")
        self.assert_problem("invalid in an unquoted YAML value")

    def test_missing_extension(self) -> None:
        self.edit("skills/actions/an-dr-dev-debug/SKILL.md", "  an-dr.type: action", "  an-dr.other: x")
        self.assert_problem("metadata has no an-dr.type")

    def test_missing_license(self) -> None:
        self.edit("skills/actions/an-dr-dev-debug/SKILL.md", "license: MIT", "license:")
        self.assert_problem("has no license")

    def test_bad_version(self) -> None:
        # Read the current version so a release that raises it keeps the test valid.
        path = "skills/actions/an-dr-dev-debug/SKILL.md"
        current = next(line for line in (self.root / path).read_text(encoding="utf-8").splitlines() if line.startswith("  version:"))
        self.edit(path, current, "  version: latest")
        self.assert_problem("must be a semantic version")

    def test_missing_author(self) -> None:
        self.edit("skills/actions/an-dr-dev-debug/SKILL.md", "  author: Andrei Gramakov (an-dr)\n", "")
        self.assert_problem("metadata has no author")


if __name__ == "__main__":
    unittest.main()
