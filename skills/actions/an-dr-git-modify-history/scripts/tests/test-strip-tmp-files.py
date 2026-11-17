"""strip-tmp-files.py removes tmp files from every commit after the base and keeps them on disk."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "strip-tmp-files.py"


class StripTmpFilesTests(unittest.TestCase):
    def test_strip(self) -> None:
        with tempfile.TemporaryDirectory(prefix="strip-tmp-") as temporary:
            work = Path(temporary)

            def git(*arguments: str) -> str:
                return subprocess.run(["git", *arguments], cwd=work, capture_output=True, text=True, check=True).stdout

            def commit(path: str, content: str, message: str) -> None:
                (work / path).parent.mkdir(parents=True, exist_ok=True)
                (work / path).write_text(content, encoding="utf-8")
                git("add", "-f", "--", path)
                git("commit", "-q", "-m", message)

            git("init", "-q", "-b", "main")
            git("config", "user.email", "test@example.invalid")
            git("config", "user.name", "Test")
            commit("README.md", "base", "chore: initial")
            git("switch", "-q", "-c", "feature/x")
            commit("tmp-agent-wip.json", "{}", "DO-NOT-MERGE: record workflow state")
            commit("feature.txt", "feature", "feat: add the feature")
            commit("docs/.tmp-ai-gen/report.html", "r", "chore: keep a report")
            commit("src/tmp_buffer.txt", "kept", "feat: add a buffer that is not a tmp file")
            author = git("log", "-1", "--format=%an %aI", "HEAD~2")

            result = subprocess.run([sys.executable, str(SCRIPT), "--base", "main"], cwd=work,
                                    capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            subjects = git("log", "--format=%s", "main..HEAD").splitlines()
            self.assertEqual(subjects, ["feat: add a buffer that is not a tmp file", "feat: add the feature"])
            names = sorted(git("log", "--format=", "--name-only", "main..HEAD").split())
            self.assertEqual(names, ["feature.txt", "src/tmp_buffer.txt"])
            self.assertEqual(git("log", "-1", "--format=%an %aI", "HEAD~1"), author, "Authorship was not kept.")
            self.assertTrue((work / "tmp-agent-wip.json").exists(), "The state file was deleted from disk.")
            self.assertIn("?? tmp-agent-wip.json", git("status", "--porcelain"), "The state file is not untracked.")

            again = subprocess.run([sys.executable, str(SCRIPT), "--base", "main"], cwd=work,
                                   capture_output=True, text=True, check=False)
            self.assertEqual(again.returncode, 0, again.stderr)
            self.assertIn("nothing to strip", again.stdout)


if __name__ == "__main__":
    unittest.main()
