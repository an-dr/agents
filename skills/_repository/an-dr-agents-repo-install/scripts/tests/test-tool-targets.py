"""Check the tool targets and the managed block shared by the install and verify scripts."""

from __future__ import annotations

import runpy
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1]
INSTALL = SCRIPTS / "install-agents.py"
VERIFY = SCRIPTS / "verify-agents.py"
ALL_IDS = ("claude", "codex", "copilot", "deepseek", "gemini", "opencode")


def load(path: Path) -> dict:
    return runpy.run_path(str(path))


class ToolTargetTests(unittest.TestCase):
    def setUp(self) -> None:
        self.module = load(INSTALL)

    def test_six_unique_targets_under_their_home(self) -> None:
        targets = self.module["tool_targets"](list(ALL_IDS))
        self.assertEqual(len(targets), 6)
        self.assertEqual(len({target.id for target in targets}), 6)
        for target in targets:
            with self.subTest(tool=target.id):
                self.assertTrue(target.id and target.name)
                self.assertTrue(target.instructions.is_relative_to(target.home))
                if target.skills_dir is not None:
                    self.assertTrue(target.skills_dir.is_relative_to(target.home))

    def test_deepseek_target_and_its_block(self) -> None:
        targets = [target for target in self.module["tool_targets"](list(ALL_IDS)) if target.id == "deepseek"]
        self.assertEqual(len(targets), 1)
        tool = targets[0]
        home = Path.home()
        self.assertEqual(tool.name, "DeepSeek Harness")
        self.assertEqual(tool.home, home / ".dsh")
        self.assertEqual(tool.instructions, home / ".dsh" / "AGENTS.md")
        self.assertEqual(tool.skills_dir, home / ".dsh" / "skills")
        # DeepSeek Harness does not expand @ imports in its instruction files.
        self.assertFalse(tool.supports_import)

        root = self.module["resolve_agents_root"](None)
        policy = root.as_posix() + "/AGENTS.md"
        block = self.module["build_block"](root, tool.supports_import)
        self.assertIn(policy, block)
        self.assertNotIn("@" + policy, block)

    def test_import_capable_tool_gets_an_at_reference(self) -> None:
        tool = self.module["tool_targets"](["claude"])[0]
        self.assertTrue(tool.supports_import)
        root = Path(self.module["default_agents_root"]())
        policy = root.as_posix() + "/AGENTS.md"
        self.assertIn("@" + policy, self.module["build_block"](root, tool.supports_import))

    def test_unknown_tool_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            self.module["tool_targets"](["unknown-tool"])


class SharedHelperCopyTests(unittest.TestCase):
    def test_both_scripts_carry_the_same_helper_copy(self) -> None:
        def region(path: Path) -> str:
            text = path.read_text(encoding="utf-8")
            start = text.index("# --- shared helpers begin ---")
            end = text.index("# --- shared helpers end ---")
            return text[start:end]

        self.assertEqual(region(INSTALL), region(VERIFY))
        self.assertEqual(load(VERIFY)["BEGIN_MARKER"], load(INSTALL)["BEGIN_MARKER"])


if __name__ == "__main__":
    unittest.main()
