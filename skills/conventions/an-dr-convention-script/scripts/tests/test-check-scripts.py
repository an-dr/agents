"""Break a disposable skill layout and check each diagnostic."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check-scripts.py"


class ScriptCheckerTests(unittest.TestCase):
    def test_runner_syntax_location_and_portability(self) -> None:
        with tempfile.TemporaryDirectory(prefix="script-check-") as temporary:
            root = Path(temporary)
            scripts = root / "skills" / "actions" / "an-dr-example" / "scripts"
            tests = scripts / "tests"
            tests.mkdir(parents=True)
            (root / "skills" / "actions" / "an-dr-other").mkdir()
            runner = tests / "run.py"
            runner.write_text("print('ok')\n", encoding="utf-8")
            script = scripts / "helper.py"
            script.write_text("print('ok')\n", encoding="utf-8")

            def check() -> subprocess.CompletedProcess[str]:
                return subprocess.run([sys.executable, str(CHECKER), "--root", str(root)], capture_output=True, text=True, check=False)

            self.assertEqual(check().returncode, 0)
            runner.unlink()
            self.assertIn("missing tests/run.py", check().stdout)
            runner.write_text("print('ok')\n", encoding="utf-8")
            script.write_text("def broken(:\n", encoding="utf-8")
            self.assertIn("Python syntax error", check().stdout)
            script.write_text("print('ok')\n", encoding="utf-8")
            misplaced = scripts / "test-misplaced.py"
            misplaced.write_text("pass\n", encoding="utf-8")
            self.assertIn("belongs in scripts/tests/", check().stdout)
            misplaced.unlink()
            script.write_text("# ../../actions/an-dr-other\n", encoding="utf-8")
            self.assertIn("guesses where an-dr-other is installed", check().stdout)


if __name__ == "__main__":
    unittest.main()
