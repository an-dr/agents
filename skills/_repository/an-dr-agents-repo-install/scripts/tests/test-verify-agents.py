"""Check the verifier's table, rows, and exit codes in a throwaway home directory."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1]
INSTALL = SCRIPTS / "install-agents.py"
VERIFY = SCRIPTS / "verify-agents.py"


class Sandbox:
    """A throwaway home and clone, so no real tool folder is touched."""

    def __init__(self) -> None:
        self.root = Path(tempfile.mkdtemp(prefix="agents-verify-"))
        self.home = self.root / "home"
        for name in (".claude", ".codex", ".gemini"):
            (self.home / name).mkdir(parents=True)
        self.clone = self.root / "clone"
        for skill in ("actions/demo-one", "conventions/demo-two"):
            (self.clone / "skills" / skill).mkdir(parents=True)
            (self.clone / "skills" / skill / "SKILL.md").write_text("---\nname: demo\n---\n", encoding="utf-8")
        (self.clone / "AGENTS.md").write_text("# policy\n", encoding="utf-8")

    def run(self, script: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
        env = {**os.environ, "HOME": str(self.home), "USERPROFILE": str(self.home)}
        return subprocess.run(
            [sys.executable, str(script), *arguments],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            env=env,
            check=False,
        )

    def install(self) -> subprocess.CompletedProcess[str]:
        return self.run(INSTALL, "--agents-root", str(self.clone))

    def verify(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return self.run(VERIFY, "--agents-root", str(self.clone), *arguments)

    def close(self) -> None:
        # Removing a file tree follows a junction, so the links go first.
        for tool in (".claude", ".codex", ".gemini"):
            skills = self.home / tool / "skills"
            if not skills.is_dir():
                continue
            for entry in skills.iterdir():
                if os.path.isjunction(entry):
                    os.rmdir(entry)
                elif entry.is_symlink():
                    os.unlink(entry)
        shutil.rmtree(self.root, ignore_errors=True)


class VerifyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.sandbox = Sandbox()
        self.addCleanup(self.sandbox.close)

    def test_healthy_install_passes_with_the_expected_table(self) -> None:
        self.assertEqual(self.sandbox.install().returncode, 0)
        result = self.sandbox.verify()
        self.assertEqual(result.returncode, 0, result.stdout)
        lines = result.stdout.splitlines()
        self.assertEqual(lines[0], "| Scope | Check | Status | Detail |")
        self.assertEqual(lines[1], "| --- | --- | --- | --- |")
        self.assertIn(f"| clone | root | pass | {self.sandbox.clone} |", result.stdout)
        self.assertIn("| clone | skills | pass | 2 skills with SKILL.md |", result.stdout)
        self.assertIn("| claude | instructions | pass |", result.stdout)
        self.assertIn("| codex | skills | pass | 2/2 linked in", result.stdout)
        self.assertIn("| gemini | skills | ◆ warn | no user-level skills directory for this tool |", result.stdout)
        self.assertTrue(result.stdout.rstrip().endswith("All checks passed, 2 warning(s)."))

    def test_missing_symlink_fails_with_a_marked_row(self) -> None:
        self.assertEqual(self.sandbox.install().returncode, 0)
        link = self.sandbox.home / ".codex" / "skills" / "demo-one"
        if os.path.isjunction(link):
            os.rmdir(link)
        else:
            os.unlink(link)

        result = self.sandbox.verify("--tools", "codex")
        self.assertEqual(result.returncode, 1)
        self.assertIn("| codex | skills | ▲ **fail** | 1/2 linked; demo-one: missing |", result.stdout)
        self.assertIn("1 check(s) failed", result.stdout)
        rows = [line for line in result.stdout.splitlines() if line.startswith("|") and "---" not in line]
        self.assertTrue(rows[1].startswith("| codex |"), rows)

    def test_missing_block_and_broken_clone_are_reported(self) -> None:
        self.assertEqual(self.sandbox.install().returncode, 0)
        (self.sandbox.home / ".claude" / "CLAUDE.md").write_text("no block\n", encoding="utf-8")

        result = self.sandbox.verify("--tools", "claude")
        self.assertEqual(result.returncode, 1)
        self.assertIn("| claude | instructions | ▲ **fail** | managed block missing or truncated |", result.stdout)
        self.assertIn("| clone | git | ◆ warn | clone is not a git repository; it cannot be updated by pull |", result.stdout)

        missing_block = self.sandbox.run(VERIFY, "--agents-root", str(self.sandbox.root / "absent"))
        self.assertEqual(missing_block.returncode, 1)
        self.assertIn("does not exist", missing_block.stderr)


if __name__ == "__main__":
    unittest.main()
