"""Verify section ownership, reader restrictions, and removal."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "wip.py"


class WipTests(unittest.TestCase):
    def test_registered_access(self) -> None:
        with tempfile.TemporaryDirectory(prefix="wip-test-") as temporary:
            root = Path(temporary)
            state = root / "state.json"
            state.write_text(json.dumps({"flow": "Vibe", "phase": "BUILD", "baseBranch": "dev"}), encoding="utf-8")
            owner = ("--section", "workflow", "--owner", "an-dr-dev-follow-workflow")

            def run(*arguments: str) -> subprocess.CompletedProcess[str]:
                return subprocess.run([sys.executable, str(SCRIPT), *arguments, "--root", str(root)], capture_output=True, text=True, check=False)

            self.assertEqual(run("get", "--section", "workflow", "--reader", "an-dr-dev-follow-workflow").stdout.strip(), "null")
            self.assertEqual(run("set", *owner, "--json-path", str(state)).returncode, 0)
            self.assertTrue((root / "tmp-agent-wip.json").is_file())
            self.assertEqual(run("get", "--section", "workflow", "--field", "phase", "--reader", "an-dr-agents-repo-verify-installation").stdout.strip(), '"BUILD"')
            whole = json.loads(run("get", "--section", "workflow", "--reader", "an-dr-dev-follow-workflow").stdout)
            self.assertEqual(whole["phase"], "BUILD")

            for label, text, arguments in (
                ("unknown section", "Unknown section", ("get", "--section", "nope", "--reader", "x")),
                ("foreign writer", "belongs to", ("set", "--section", "workflow", "--owner", "an-dr-dev-integrate", "--json-path", str(state))),
                ("unlisted reader", "may not read section", ("get", "--section", "workflow", "--field", "phase", "--reader", "an-dr-dev-review")),
                ("unlisted field", "may not read 'workflow.baseBranch'", ("get", "--section", "workflow", "--field", "baseBranch", "--reader", "an-dr-agents-repo-verify-installation")),
                ("whole-section read", "named fields", ("get", "--section", "workflow", "--reader", "an-dr-agents-repo-verify-installation")),
            ):
                with self.subTest(label=label):
                    result = run(*arguments)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(text, result.stderr)
            state.write_text('{"flow":"Vibe","invented":1}', encoding="utf-8")
            unknown = run("set", *owner, "--json-path", str(state))
            self.assertNotEqual(unknown.returncode, 0)
            self.assertIn("has no field", unknown.stderr)
            self.assertEqual(run("remove", *owner).returncode, 0)
            self.assertFalse((root / "tmp-agent-wip.json").exists())


if __name__ == "__main__":
    unittest.main()
