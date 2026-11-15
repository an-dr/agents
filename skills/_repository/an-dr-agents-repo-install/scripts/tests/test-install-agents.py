"""Check the installer end to end in a throwaway home directory."""

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
BEGIN = "<!-- BEGIN agents-install -->"
END = "<!-- END agents-install -->"


class Sandbox:
    """A throwaway home and clone, so no real tool folder is touched."""

    def __init__(self) -> None:
        self.root = Path(tempfile.mkdtemp(prefix="agents-install-"))
        self.home = self.root / "home"
        for name in (".claude", ".codex"):
            (self.home / name).mkdir(parents=True)
        self.clone = self.root / "clone"
        for skill in ("actions/demo-one", "conventions/demo-two"):
            (self.clone / "skills" / skill).mkdir(parents=True)
            (self.clone / "skills" / skill / "SKILL.md").write_text("---\nname: demo\n---\n", encoding="utf-8")
        (self.clone / "AGENTS.md").write_text("# policy\n", encoding="utf-8")

    def env(self) -> dict[str, str]:
        return {**os.environ, "HOME": str(self.home), "USERPROFILE": str(self.home)}

    def run(self, script: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(script), *arguments],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            env=self.env(),
            check=False,
        )

    def instructions(self, tool: str) -> Path:
        name = "CLAUDE.md" if tool == ".claude" else "AGENTS.md"
        return self.home / tool / name

    def link(self, tool: str, skill: str) -> Path:
        return self.home / tool / "skills" / skill

    def close(self) -> None:
        # Removing a file tree follows a junction, so the links go first.
        for tool in (".claude", ".codex"):
            skills = self.home / tool / "skills"
            if not skills.is_dir():
                continue
            for entry in skills.iterdir():
                if os.path.isjunction(entry):
                    os.rmdir(entry)
                elif entry.is_symlink():
                    os.unlink(entry)
        shutil.rmtree(self.root, ignore_errors=True)


class InstallTests(unittest.TestCase):
    def setUp(self) -> None:
        self.sandbox = Sandbox()
        self.addCleanup(self.sandbox.close)

    def install(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return self.sandbox.run(INSTALL, "--agents-root", str(self.sandbox.clone), *arguments)

    def test_install_writes_blocks_and_links_then_stays_current(self) -> None:
        first = self.install()
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertIn(f"Agents root: {self.sandbox.clone}", first.stdout)
        self.assertIn("Tools: Claude Code, Codex", first.stdout)
        for tool in (".claude", ".codex"):
            with self.subTest(tool=tool):
                content = self.sandbox.instructions(tool).read_text(encoding="utf-8")
                self.assertTrue(content.startswith(BEGIN))
                self.assertTrue(content.endswith(END + "\n"))
                self.assertIn(self.sandbox.clone.as_posix() + "/AGENTS.md", content)
                for skill in ("demo-one", "demo-two"):
                    self.assertTrue((self.sandbox.link(tool, skill) / "SKILL.md").is_file())
                self.assertIn("created=2", first.stdout)

        second = self.install()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertIn("instructions  current", second.stdout)
        self.assertIn("skills        current=2", second.stdout)

    def test_existing_content_survives_and_the_block_is_replaced(self) -> None:
        instructions = self.sandbox.instructions(".claude")
        instructions.write_text("user text\n\n" + BEGIN + "\nold\n" + END + "\n", encoding="utf-8")
        result = self.install("--tools", "claude")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("instructions  updated", result.stdout)
        content = instructions.read_text(encoding="utf-8")
        self.assertTrue(content.startswith("user text\n\n"))
        self.assertIn("## Global agent workflow", content)
        self.assertNotIn("old", content)

    def test_skip_skills_writes_blocks_only(self) -> None:
        result = self.install("--skip-skills")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("skills        skipped", result.stdout)
        self.assertTrue(self.sandbox.instructions(".codex").is_file())
        self.assertFalse((self.sandbox.home / ".codex" / "skills").exists())

    def test_conflict_exits_two_and_force_replaces_the_directory(self) -> None:
        real = self.sandbox.link(".claude", "demo-one")
        real.mkdir(parents=True)
        (real / "keep.txt").write_text("real\n", encoding="utf-8")

        conflict = self.install("--tools", "claude")
        self.assertEqual(conflict.returncode, 2, conflict.stderr)
        self.assertIn("## Conflicts", conflict.stdout)
        self.assertIn("exists as a real directory (conflict)", conflict.stdout)
        self.assertIn("re-run with --force", conflict.stdout)
        self.assertTrue((real / "keep.txt").is_file())

        forced = self.install("--tools", "claude", "--force")
        self.assertEqual(forced.returncode, 0, forced.stderr)
        self.assertTrue((self.sandbox.link(".claude", "demo-one") / "SKILL.md").is_file())
        self.assertFalse((real / "keep.txt").exists())

    def test_uninstall_removes_links_and_blocks(self) -> None:
        self.assertEqual(self.install().returncode, 0)
        result = self.install("--uninstall")
        self.assertEqual(result.returncode, 0, result.stderr)
        for tool in (".claude", ".codex"):
            with self.subTest(tool=tool):
                self.assertIn("instructions  removed", result.stdout)
                self.assertFalse(self.sandbox.instructions(tool).exists())
                self.assertFalse(os.path.lexists(self.sandbox.link(tool, "demo-one")))

    def test_stale_clone_link_is_pruned(self) -> None:
        stale = self.sandbox.link(".codex", "demo-gone")
        stale.parent.mkdir(parents=True, exist_ok=True)
        (self.sandbox.clone / "skills" / "actions" / "demo-gone").mkdir(parents=True)
        (self.sandbox.clone / "skills" / "actions" / "demo-gone" / "SKILL.md").write_text("gone\n", encoding="utf-8")
        self.assertEqual(self.install("--tools", "codex").returncode, 0)
        (self.sandbox.clone / "skills" / "actions" / "demo-gone").rename(self.sandbox.root / "moved-away")

        result = self.install("--tools", "codex")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("pruned        demo-gone", result.stdout)
        self.assertFalse(os.path.lexists(stale))

    def test_unknown_tool_and_missing_root_are_reported(self) -> None:
        unknown = self.install("--tools", "unknown-tool")
        self.assertEqual(unknown.returncode, 1)
        self.assertIn("Unknown tool id(s): unknown-tool", unknown.stderr)
        self.assertIn("Known ids: claude, codex, copilot, deepseek, gemini, opencode", unknown.stderr)

        missing = self.sandbox.run(INSTALL, "--agents-root", str(self.sandbox.root / "absent"))
        self.assertEqual(missing.returncode, 1)
        self.assertIn("does not exist", missing.stderr)

    def test_no_detected_tool_is_reported(self) -> None:
        empty = self.sandbox.root / "empty-home"
        empty.mkdir()
        env = {**os.environ, "HOME": str(empty), "USERPROFILE": str(empty)}
        result = subprocess.run(
            [sys.executable, str(INSTALL), "--agents-root", str(self.sandbox.clone)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            env=env,
            check=False,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("No supported tool found", result.stderr)


if __name__ == "__main__":
    unittest.main()
