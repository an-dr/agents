"""Exercise the staleness check on a disposable Git repository."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "check-main-staleness.py"


def git(root: Path, *arguments: str, date: str | None = None) -> None:
    env = dict(os.environ)
    if date:
        env["GIT_COMMITTER_DATE"] = env["GIT_AUTHOR_DATE"] = date
    subprocess.run(
        ["git", "-C", str(root), "-c", "user.name=test", "-c", "user.email=test@example.invalid", *arguments],
        check=True, capture_output=True, text=True, env=env,
    )


def run(root: Path, *extra: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(SCRIPT), "--root", str(root), *extra], capture_output=True, text=True, encoding="utf-8")


class StalenessTests(unittest.TestCase):
    def repository(self, date: str, dev_commits: int) -> tempfile.TemporaryDirectory:
        temporary = tempfile.TemporaryDirectory(prefix="staleness-")
        root = Path(temporary.name)
        git(root, "init", "--quiet", "-b", "main")
        git(root, "commit", "--quiet", "--allow-empty", "-m", "base", date=date)
        git(root, "switch", "--quiet", "-c", "dev")
        for number in range(dev_commits):
            git(root, "commit", "--quiet", "--allow-empty", "-m", f"change {number}")
        return temporary

    def test_old_main_with_unpromoted_commits_is_stale(self) -> None:
        with self.repository("2020-01-01T00:00:00", 1) as path:
            result = run(Path(path))
            self.assertEqual(result.returncode, 1, result.stdout)
            self.assertIn("is stale", result.stdout)

    def test_fresh_main_within_limits_is_ok(self) -> None:
        with self.repository("2090-01-01T00:00:00", 2) as path:
            result = run(Path(path))
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("within the limits", result.stdout)

    def test_too_many_commits_is_stale(self) -> None:
        with self.repository("2090-01-01T00:00:00", 3) as path:
            self.assertEqual(run(Path(path), "--max-commits", "2").returncode, 1)

    def test_old_main_with_nothing_to_promote_is_current(self) -> None:
        with self.repository("2020-01-01T00:00:00", 0) as path:
            result = run(Path(path))
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("is current", result.stdout)

    def test_missing_dev_branch_fails(self) -> None:
        with tempfile.TemporaryDirectory(prefix="staleness-") as path:
            git(Path(path), "init", "--quiet", "-b", "main")
            git(Path(path), "commit", "--quiet", "--allow-empty", "-m", "base")
            self.assertEqual(run(Path(path)).returncode, 2)


if __name__ == "__main__":
    unittest.main()
