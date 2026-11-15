"""Break a disposable copy of the repository one way at a time and expect a named break."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[5]
CHECKER = Path(__file__).resolve().parents[1] / "check-registration.py"
IGNORED = shutil.ignore_patterns("scripts", "assets", "fixtures", "*.zip")
CYCLE = "an-dr-dev-debug -> an-dr-dev-implement-adversarial-ut -> an-dr-dev-debug"


class RegistrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="check-registration-")
        self.root = Path(self.temporary.name)
        self.new_fixture()

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def new_fixture(self) -> None:
        shutil.rmtree(self.root / "skills", ignore_errors=True)
        shutil.copytree(REPOSITORY / "skills", self.root / "skills", ignore=IGNORED)

    def edit(self, path: str, old: str, new: str) -> None:
        file = self.root / path
        text = file.read_text(encoding="utf-8")
        self.assertIn(old, text, f"Fixture text '{old}' not found in {path}.")
        file.write_text(text.replace(old, new), encoding="utf-8")

    def append(self, path: str, text: str) -> None:
        with (self.root / path).open("a", encoding="utf-8") as stream:
            stream.write(f"\n{text}\n")

    def run_checker(self, *arguments: str) -> tuple[int, str]:
        result = subprocess.run(
            [sys.executable, str(CHECKER), "--root", str(self.root), *arguments],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
        return result.returncode, result.stdout + result.stderr

    def assert_check(self, case: str, expected_exit: int, expected_text: str, *arguments: str) -> None:
        code, output = self.run_checker(*arguments)
        self.assertEqual(code, expected_exit, f"{case}: exit {code}, expected {expected_exit}.\n{output}")
        if expected_text:
            self.assertIn(expected_text, output, f"{case}: output lacks '{expected_text}'.\n{output}")

    def test_clean_copy(self) -> None:
        self.assert_check("clean copy", 0, "Registration check passed")

    def test_unregistered_folder(self) -> None:
        folder = self.root / "skills/actions/an-dr-dev-unregistered"
        folder.mkdir()
        (folder / "SKILL.md").write_text("---\nname: an-dr-dev-unregistered\n---\n", encoding="utf-8")
        self.assert_check("unregistered folder", 1, "missing from the skills/README.md table")

    def test_unknown_category(self) -> None:
        (self.root / "skills/loose").mkdir()
        self.assert_check("unknown category", 1, "is not a category folder")

    def test_folder_and_type_disagree(self) -> None:
        (self.root / "skills/actions/an-dr-dev-debug").rename(self.root / "skills/concepts/an-dr-dev-debug")
        self.assert_check("folder and type disagree", 1, "is a action but sits in concepts")

    def test_invalid_type(self) -> None:
        self.edit("skills/actions/an-dr-dev-debug/SKILL.md", "an-dr.type: action", "an-dr.type: tool")
        self.assert_check("invalid type", 1, "an-dr.type is 'tool'")

    def test_concept_name_lacks_its_type(self) -> None:
        (self.root / "skills/concepts/an-dr-concept-ai-slop").rename(self.root / "skills/concepts/an-dr-ai-slop")
        self.assert_check("concept name lacks its type", 1, "is a concept, so its name needs 'concept-'")

    def test_concept_with_a_script(self) -> None:
        (self.root / "skills/concepts/an-dr-concept-ai-slop/helper.py").write_text("# helper", encoding="utf-8")
        self.assert_check("concept with a script", 1, "a concept allows only SKILL.md, README.md, and evals/")

    def test_general_skill_depends_on_a_repository_skill(self) -> None:
        self.edit("skills/actions/an-dr-dev-test/SKILL.md", "an-dr.dependencies: ", "an-dr.dependencies: an-dr-agents-repo-install ")
        self.append("skills/actions/an-dr-dev-test/SKILL.md", "See `an-dr-agents-repo-install`.")
        self.assert_check("general skill depends on a repository skill", 1, "a skill of the repository itself")

    def test_undeclared_skill(self) -> None:
        self.edit("skills/actions/an-dr-dev-integrate/SKILL.md", "commit-message an-dr-git-modify-history", "commit-message")
        self.assert_check("undeclared skill", 1, "names an-dr-git-modify-history but does not declare it in dependencies")

    def test_unused_declaration(self) -> None:
        self.edit("skills/actions/an-dr-dev-implement-adversarial-ut/SKILL.md", "an-dr.dependencies: none", "an-dr.dependencies: an-dr-dev-debug")
        self.assert_check("unused declaration", 1, "declares an-dr-dev-debug but never names it")

    def test_prohibited_skill_names_another(self) -> None:
        self.append("skills/concepts/an-dr-concept-evidence-grounding/SKILL.md", "See `an-dr-dev-implement-code` for more.")
        self.assert_check("prohibited skill names another", 1, "is PROHIBITED from depending on other skills but names an-dr-dev-implement-code")

    def test_cycle_is_reported_and_can_fail(self) -> None:
        self.edit("skills/actions/an-dr-dev-implement-adversarial-ut/SKILL.md", "an-dr.dependencies: none", "an-dr.dependencies: an-dr-dev-debug")
        self.append("skills/actions/an-dr-dev-implement-adversarial-ut/SKILL.md", "Pair it with `an-dr-dev-debug`.")
        self.edit("skills/actions/an-dr-dev-debug/SKILL.md", "an-dr.dependencies: none", "an-dr.dependencies: an-dr-dev-implement-adversarial-ut")
        self.append("skills/actions/an-dr-dev-debug/SKILL.md", "Pair it with `an-dr-dev-implement-adversarial-ut`.")
        self.assert_check("cycle is reported", 0, CYCLE)
        self.assert_check("cycle fails on request", 1, CYCLE, "--fail-on-cycle")

    def test_layout_path(self) -> None:
        self.edit("skills/actions/an-dr-files-make-screengif/SKILL.md", "<skill>/", "agents/skills/an-dr-files-make-screengif/")
        self.assert_check("layout path", 1, "repository-layout path")

    def test_root_code(self) -> None:
        (self.root / "lib").mkdir()
        (self.root / "lib/Shared.py").write_text("# shared", encoding="utf-8")
        self.assert_check("root code", 1, "code outside skills/")

    def test_required_tests(self) -> None:
        self.assert_check("all skills have test suites, including concepts", 0, "Registration check passed", "--require-tests")

    def test_missing_test_suite(self) -> None:
        (self.root / "skills/actions/an-dr-dev-debug/evals").rename(self.root / "skills/actions/an-dr-dev-debug/tests-disabled")
        self.assert_check("missing tests folder", 1, "missing evals/evals.json", "--require-tests")

    def test_missing_concept_cases(self) -> None:
        (self.root / "skills/concepts/an-dr-concept-ai-slop/evals/evals.json").rename(
            self.root / "skills/concepts/an-dr-concept-ai-slop/evals/cases-disabled.json"
        )
        self.assert_check("missing concept cases", 1, "missing evals/evals.json", "--require-tests")

    def test_missing_evaluation_intent(self) -> None:
        (self.root / "skills/concepts/an-dr-concept-ai-slop/evals/EVAL.md").rename(
            self.root / "skills/concepts/an-dr-concept-ai-slop/evals/intent-disabled.md"
        )
        self.assert_check("missing evaluation intent", 1, "missing evals/EVAL.md", "--require-tests")


if __name__ == "__main__":
    unittest.main()
