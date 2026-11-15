"""A work branch started from dev carries tmp-agent-wip.json and other tmp files.

Integration finds dev from the state, strips every tmp file from every commit,
refuses to land while any remains, and lands on dev.
"""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1]
WIP_DATA_SKILL = Path(__file__).resolve().parents[3] / "an-dr-ai-use-wip-data"
STATE = '{ "schemaVersion": 1, "sections": { "workflow": { "flow": "Vibe", "baseBranch": "dev" } } }'


class TmpFilesTests(unittest.TestCase):
    def test_tmp_files(self) -> None:
        with tempfile.TemporaryDirectory(prefix="integrate-tmp-") as temporary:
            origin = Path(temporary) / "origin.git"
            work = Path(temporary) / "work"

            def run(command: list[str]) -> subprocess.CompletedProcess:
                return subprocess.run(command, cwd=work, capture_output=True, text=True, check=False)

            def git(*arguments: str) -> subprocess.CompletedProcess:
                return run(["git", *arguments])

            def step(script: str, arguments: list[str] | None = None) -> subprocess.CompletedProcess:
                command = [sys.executable, str(SCRIPTS / script), *(arguments or []), "--wip-data-skill", str(WIP_DATA_SKILL)]
                return run(command)

            def save_commit(path: str, content: str, message: str) -> None:
                full = work / path
                full.parent.mkdir(parents=True, exist_ok=True)
                full.write_text(content, encoding="utf-8")
                git("add", "-f", "--", path)
                git("commit", "-q", "-m", message)

            subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(origin)], capture_output=True, text=True, check=True)
            subprocess.run(["git", "clone", "-q", str(origin), str(work)], capture_output=True, text=True, check=True)
            git("config", "user.email", "test@example.invalid")
            git("config", "user.name", "Test")
            save_commit("README.md", "base", "chore: initial")
            git("push", "-q", "origin", "main")
            git("switch", "-q", "-c", "dev")
            save_commit("dev.txt", "dev", "chore: dev work")
            git("push", "-q", "-u", "origin", "dev")
            git("switch", "-q", "-c", "vibe/x")
            save_commit("tmp-agent-wip.json", STATE, "chore: record workflow state")
            save_commit("feature.txt", "feature", "feat: add the feature")
            save_commit("docs/.tmp-ai-gen/report.html", "r", "chore: keep a report")
            save_commit("src/tmp_buffer.txt", "kept", "feat: add a buffer that is not a tmp file")

            check = step("integrate-1-check.py")
            output = check.stdout + check.stderr
            self.assertEqual(check.returncode, 0, f"The base was not read from the state: {output}")
            self.assertIn("Base branch: dev", output, "The base was not read from the state.")
            self.assertIn("tmp-agent-wip.json", output, "The check did not list the tmp files.")

            early = step("integrate-4-finish.py", ["--mode", "Commits"])
            early_output = early.stdout + early.stderr
            self.assertNotEqual(early.returncode, 0, f"finish landed tmp files: {early_output}")
            self.assertIn("still carries tmp files", early_output)

            rebase = step("integrate-3-rebase.py")
            rebase_output = rebase.stdout + rebase.stderr
            self.assertEqual(rebase.returncode, 0, f"rebase failed: {rebase_output}")
            left = [line for line in git("log", "--format=", "--name-only", "dev..HEAD").stdout.splitlines()
                    if re.search(r"(^|/)\.?tmp-", line)]
            self.assertEqual(left, [], f"tmp files survived: {', '.join(left)}")
            self.assertFalse((work / "tmp-agent-wip.json").exists(), "The state file stayed on disk.")
            self.assertTrue((work / "src/tmp_buffer.txt").exists(), "A file that only contains tmp was stripped.")
            subjects = git("log", "--format=%s", "dev..HEAD").stdout.splitlines()
            self.assertNotIn("chore: record workflow state", subjects, "A tmp-only commit was kept.")
            self.assertIn("feat: add the feature", subjects, "A real commit was lost.")
            recorded = git("config", "--get", "branch.vibe/x.an-dr-base").stdout.strip()
            self.assertEqual(recorded, "dev", "The base was not recorded in the branch config.")

            finish = step("integrate-4-finish.py", ["--mode", "Commits"])
            finish_output = finish.stdout + finish.stderr
            self.assertEqual(finish.returncode, 0, f"finish failed: {finish_output}")
            self.assertEqual(git("branch", "--show-current").stdout.strip(), "dev", "The branch did not land on dev.")
            self.assertTrue((work / "feature.txt").exists(), "dev does not have the feature.")
            self.assertNotEqual(git("rev-parse", "main").stdout, git("rev-parse", "dev").stdout, "main moved.")

        print("Tmp-file checks passed: base from state, strip, refusal, landing on dev.")


if __name__ == "__main__":
    unittest.main()
