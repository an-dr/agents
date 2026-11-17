"""A handed-over branch lands without its DO-NOT-MERGE tip, and a branch that was not handed over cleanly is refused.

The base is read from the state in the DO-NOT-MERGE commit, so a fresh clone with no branch config
lands on the right base.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1]
WIP_DATA_SKILL = str(SCRIPTS.parents[1] / "an-dr-ai-use-wip-data")
STATE = '{ "schemaVersion": 1, "sections": { "workflow": { "flow": "Vibe", "baseBranch": "dev" } } }'


class Branch:
    """A clone with main and dev on its origin and a feature branch cut from dev."""

    def __init__(self, temporary: str) -> None:
        origin = Path(temporary) / "origin.git"
        self.work = Path(temporary) / "work"
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(origin)], capture_output=True, check=True)
        subprocess.run(["git", "clone", "-q", str(origin), str(self.work)], capture_output=True, check=True)
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "user.name", "Test")
        self.commit("README.md", "base", "chore: initial")
        self.git("push", "-q", "origin", "main")
        self.git("switch", "-q", "-c", "dev")
        self.commit("dev.txt", "dev", "chore: dev work")
        self.git("push", "-q", "-u", "origin", "dev")
        self.git("switch", "-q", "-c", "feature/x")

    def git(self, *arguments: str) -> subprocess.CompletedProcess:
        return subprocess.run(["git", *arguments], cwd=self.work, capture_output=True, text=True, check=False)

    def commit(self, path: str, content: str, message: str) -> None:
        full = self.work / path
        full.parent.mkdir(parents=True, exist_ok=True)
        full.write_text(content, encoding="utf-8")
        self.git("add", "-f", "--", path)
        self.git("commit", "-q", "-m", message)

    def hand_over(self) -> None:
        self.commit("tmp-agent-wip.json", STATE, "DO-NOT-MERGE: record workflow state")

    def step(self, script: str, *arguments: str) -> tuple[int, str]:
        command = [sys.executable, str(SCRIPTS / script), "--wip-data-skill", WIP_DATA_SKILL, *arguments]
        result = subprocess.run(command, cwd=self.work, capture_output=True, text=True, check=False)
        return result.returncode, result.stdout + result.stderr


class LandingTests(unittest.TestCase):
    def test_handed_over_branch_lands_without_its_state(self) -> None:
        with tempfile.TemporaryDirectory(prefix="integrate-land-") as temporary:
            branch = Branch(temporary)
            branch.commit("feature.txt", "feature", "feat: add the feature")
            branch.commit("src/tmp_buffer.txt", "kept", "feat: add a buffer that is not a tmp file")
            branch.hand_over()

            code, output = branch.step("integrate-1-check.py")
            self.assertEqual(code, 0, output)
            self.assertIn("Base branch: dev", output, "The base was not read from the handed-over state.")
            self.assertIn("DO-NOT-MERGE: record workflow state", output, "The check did not list the commit to drop.")

            code, output = branch.step("integrate-4-finish.py", "--mode", "Commits")
            self.assertNotEqual(code, 0, f"finish landed a DO-NOT-MERGE commit: {output}")

            code, output = branch.step("integrate-3-rebase.py")
            self.assertEqual(code, 0, output)
            self.assertFalse((branch.work / "tmp-agent-wip.json").exists(), "The state file stayed on disk.")
            self.assertEqual(branch.git("config", "--get", "branch.feature/x.an-dr-base").stdout.strip(), "dev")

            code, output = branch.step("integrate-4-finish.py", "--mode", "Commits")
            self.assertEqual(code, 0, output)
            self.assertEqual(branch.git("branch", "--show-current").stdout.strip(), "dev")
            subjects = branch.git("log", "--format=%s", "main..dev").stdout.splitlines()
            self.assertIn("feat: add the feature", subjects)
            self.assertNotIn("DO-NOT-MERGE: record workflow state", subjects)
            self.assertTrue((branch.work / "src/tmp_buffer.txt").exists(), "A file that only contains tmp was lost.")

    def assert_refused(self, build, expected: str) -> None:
        with tempfile.TemporaryDirectory(prefix="integrate-refuse-") as temporary:
            branch = Branch(temporary)
            build(branch)
            head = branch.git("rev-parse", "HEAD").stdout
            for script in ("integrate-1-check.py", "integrate-3-rebase.py"):
                code, output = branch.step(script)
                self.assertNotEqual(code, 0, f"{script} accepted the branch: {output}")
                self.assertIn(expected, output)
            self.assertEqual(branch.git("rev-parse", "HEAD").stdout, head, "A refused branch was changed.")

    def test_revert_is_refused(self) -> None:
        def build(branch: Branch) -> None:
            branch.commit("feature.txt", "feature", "feat: add the feature")
            branch.git("revert", "--no-edit", "HEAD")
            branch.hand_over()
        self.assert_refused(build, "is a revert")

    def test_revert_type_is_refused(self) -> None:
        def build(branch: Branch) -> None:
            branch.commit("feature.txt", "feature", "revert(core): undo the feature")
            branch.hand_over()
        self.assert_refused(build, "is a revert")

    def test_tmp_file_in_landing_commit_is_refused(self) -> None:
        def build(branch: Branch) -> None:
            branch.commit("docs/.tmp-ai-gen/report.html", "r", "chore: keep a report")
            branch.hand_over()
        self.assert_refused(build, "carry tmp files")

    def test_do_not_merge_below_work_is_refused(self) -> None:
        def build(branch: Branch) -> None:
            branch.hand_over()
            branch.commit("feature.txt", "feature", "feat: add the feature")
        self.assert_refused(build, "below work that lands")

    def test_do_not_merge_with_real_changes_is_refused(self) -> None:
        def build(branch: Branch) -> None:
            branch.commit("feature.txt", "feature", "feat: add the feature")
            branch.hand_over()
            branch.commit("debug.txt", "local only", "DO-NOT-MERGE: keep a debug switch")
        self.assert_refused(build, "changes files beyond tmp ones")


if __name__ == "__main__":
    unittest.main()
