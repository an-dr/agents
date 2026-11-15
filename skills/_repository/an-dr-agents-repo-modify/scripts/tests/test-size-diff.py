"""Exercise the size report on a disposable Git repository."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "size-diff.py"


def git(root: Path, *arguments: str) -> None:
    subprocess.run(["git", "-C", str(root), *arguments], check=True, capture_output=True, text=True)


class SizeDiffTests(unittest.TestCase):
    def test_changed_instruction_and_new_reference(self) -> None:
        with tempfile.TemporaryDirectory(prefix="size-diff-") as temporary:
            root = Path(temporary)
            skill = root / "skills" / "actions" / "an-dr-example"
            skill.mkdir(parents=True)
            (root / "AGENTS.md").write_text("a" * 39 + "—", encoding="utf-8")
            (skill / "SKILL.md").write_text("---\ndescription: " + "d" * 40 + "\n---\n", encoding="utf-8")
            git(root, "init", "--quiet")
            git(root, "-c", "core.autocrlf=false", "add", "-A")
            git(root, "-c", "user.name=test", "-c", "user.email=test@example.invalid", "commit", "--quiet", "-m", "baseline")

            empty = subprocess.run([sys.executable, str(SCRIPT), "--root", str(root)], capture_output=True, text=True, encoding="utf-8")
            self.assertEqual(empty.returncode, 0, empty.stderr)
            self.assertIn("| changed files | 0 | 0 | 0 |", empty.stdout)

            (root / "AGENTS.md").write_text("a" * 79 + "—", encoding="utf-8")
            reference = skill / "references" / "mode.md"
            reference.parent.mkdir()
            reference.write_text("r" * 80, encoding="utf-8")
            result = subprocess.run([sys.executable, str(SCRIPT), "--root", str(root)], capture_output=True, text=True, encoding="utf-8")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("| `AGENTS.md` | 10 | 20 | +10 |", result.stdout)
            self.assertIn("| `skills/actions/an-dr-example/references/mode.md` | 0 | 20 | +20 |", result.stdout)
            self.assertNotIn("`skills/actions/an-dr-example/SKILL.md`", result.stdout)
            self.assertIn("| always loaded | 20 | 30 | +10 |", result.stdout)

    def test_unknown_base_fails(self) -> None:
        with tempfile.TemporaryDirectory(prefix="size-diff-") as temporary:
            root = Path(temporary)
            git(root, "init", "--quiet")
            result = subprocess.run([sys.executable, str(SCRIPT), "--root", str(root), "--base", "missing"], capture_output=True, text=True, encoding="utf-8")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Unknown --base 'missing'", result.stderr)


if __name__ == "__main__":
    unittest.main()
