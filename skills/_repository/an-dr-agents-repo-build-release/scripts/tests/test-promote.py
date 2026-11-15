"""Exercise promotion on a disposable Git repository."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "promote.py"
SCRIPTS = tempfile.TemporaryDirectory(prefix="promote-scripts-")
(Path(SCRIPTS.name) / "ok.py").write_text("", encoding="utf-8")
(Path(SCRIPTS.name) / "bad.py").write_text("raise SystemExit(1)\n", encoding="utf-8")
PASS = [sys.executable, str(Path(SCRIPTS.name) / "ok.py")]
FAIL = [sys.executable, str(Path(SCRIPTS.name) / "bad.py")]


def git(root: Path, *arguments: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), "-c", "user.name=test", "-c", "user.email=test@example.invalid", *arguments],
        check=True, capture_output=True, text=True,
    )
    return result.stdout.strip()


def promote(root: Path, *extra: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(SCRIPT), "--root", str(root), "--no-push", *extra], capture_output=True, text=True, encoding="utf-8")


class PromoteTests(unittest.TestCase):
    def repository(self) -> tempfile.TemporaryDirectory:
        temporary = tempfile.TemporaryDirectory(prefix="promote-")
        root = Path(temporary.name)
        git(root, "init", "--quiet", "-b", "main")
        git(root, "commit", "--quiet", "--allow-empty", "-m", "base")
        git(root, "switch", "--quiet", "-c", "dev")
        git(root, "commit", "--quiet", "--allow-empty", "-m", "change")
        return temporary

    def test_passing_tests_move_main(self) -> None:
        with self.repository() as path:
            root = Path(path)
            result = promote(root, "--test-command", *PASS)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(git(root, "rev-parse", "main"), git(root, "rev-parse", "dev"))

    def test_failing_tests_leave_main(self) -> None:
        with self.repository() as path:
            root = Path(path)
            before = git(root, "rev-parse", "main")
            result = promote(root, "--test-command", *FAIL)
            self.assertEqual(result.returncode, 1)
            self.assertIn("did not move", result.stderr)
            self.assertEqual(git(root, "rev-parse", "main"), before)

    def test_dirty_tree_is_refused(self) -> None:
        with self.repository() as path:
            root = Path(path)
            (root / "scratch.txt").write_text("x", encoding="utf-8")
            result = promote(root, "--test-command", *PASS)
            self.assertEqual(result.returncode, 1)
            self.assertIn("not clean", result.stderr)

    def test_diverged_main_is_refused(self) -> None:
        with self.repository() as path:
            root = Path(path)
            git(root, "switch", "--quiet", "main")
            git(root, "commit", "--quiet", "--allow-empty", "-m", "hotfix")
            git(root, "switch", "--quiet", "dev")
            result = promote(root, "--test-command", *PASS)
            self.assertEqual(result.returncode, 1)
            self.assertIn("no fast-forward", result.stderr)

    def test_wrong_branch_is_refused(self) -> None:
        with self.repository() as path:
            root = Path(path)
            git(root, "switch", "--quiet", "main")
            self.assertEqual(promote(root, "--test-command", *PASS).returncode, 1)


if __name__ == "__main__":
    unittest.main()
