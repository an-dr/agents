"""Check the local Python test runner's discovery and failure reporting."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


RUNNER = Path(__file__).resolve().parent / "run.py"


class RunnerTests(unittest.TestCase):
    def test_pass_failure_exit_and_top_level_discovery(self) -> None:
        with tempfile.TemporaryDirectory(prefix="local-runner-") as temporary:
            root = Path(temporary)

            def invoke(folder: str) -> subprocess.CompletedProcess[str]:
                return subprocess.run([sys.executable, str(RUNNER), "--tests-path", str(root / folder)], capture_output=True, text=True, check=False)

            passing = root / "passing"
            passing.mkdir()
            (passing / "test-ok.py").write_text("print('ok')\n", encoding="utf-8")
            nested = passing / "fixtures"
            nested.mkdir()
            (nested / "test-fail.py").write_text("raise RuntimeError('fixture must not run')\n", encoding="utf-8")
            result = invoke("passing")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("1 of 1 script test(s) passed", result.stdout)

            failing = root / "failing"
            failing.mkdir()
            (failing / "test-error.py").write_text("raise RuntimeError('expected fixture failure')\n", encoding="utf-8")
            result = invoke("failing")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("expected fixture failure", result.stdout)

            (failing / "test-error.py").write_text("raise SystemExit(7)\n", encoding="utf-8")
            result = invoke("failing")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("FAIL (exit 7)", result.stdout)

            (failing / "test-z-ok.py").write_text("print('ok')\n", encoding="utf-8")
            result = invoke("failing")
            self.assertIn("| `test-z-ok.py` | pass |", result.stdout)
            self.assertNotEqual(result.returncode, 0)

            empty = root / "empty"
            empty.mkdir()
            self.assertIn("No script tests found", invoke("empty").stderr)
            self.assertIn("Tests folder not found", invoke("missing").stderr)


if __name__ == "__main__":
    unittest.main()
