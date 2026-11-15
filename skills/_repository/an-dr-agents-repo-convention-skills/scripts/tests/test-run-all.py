"""Exercise root suite discovery and affected-suite selection."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT_RUNNER = Path(__file__).resolve().parents[5] / "tests" / "run-all.py"


class RootRunnerTests(unittest.TestCase):
    def test_discovery_and_selection(self) -> None:
        with tempfile.TemporaryDirectory(prefix="agents-test-discovery-") as temporary:
            root = Path(temporary)
            tests = root / "tests"
            tests.mkdir()
            shutil.copyfile(ROOT_RUNNER, tests / "run-all.py")

            def suite(category: str, name: str, body: str = "print('ran')\n", dependency: str | None = None) -> Path:
                skill = root / "skills" / category / name
                runner = skill / "scripts" / "tests" / "run.py"
                runner.parent.mkdir(parents=True)
                metadata = f"metadata:\n  an-dr.dependencies: {dependency}\n" if dependency else ""
                (skill / "SKILL.md").write_text(f"---\nname: {name}\n{metadata}---\n", encoding="utf-8")
                runner.write_text(body, encoding="utf-8")
                return skill

            def run(*arguments: str) -> subprocess.CompletedProcess[str]:
                return subprocess.run([sys.executable, str(tests / "run-all.py"), *arguments], capture_output=True, text=True, check=False)

            result = run()
            self.assertEqual(result.returncode, 1)
            self.assertIn("No conventional skill test runners", result.stderr)
            first = suite("actions", "example-one")
            result = run()
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("example-one/scripts/tests/run.py", result.stdout)
            second = suite("_custom", "example-two")
            result = run()
            self.assertIn("2 of 2 step(s) passed", result.stdout)
            fixture = first / "scripts/tests/fixtures/fake/scripts/tests"
            fixture.mkdir(parents=True)
            (fixture.parent.parent / "SKILL.md").write_text("# Fixture\n", encoding="utf-8")
            (fixture / "run.py").write_text("raise RuntimeError('nested fixture executed')\n", encoding="utf-8")
            (first / "scripts/tests/test-trap.py").write_text("raise RuntimeError('loose test executed')\n", encoding="utf-8")
            self.assertIn("2 of 2 step(s) passed", run().stdout)
            runner = first / "scripts/tests/run.py"
            runner.rename(runner.with_name("disabled.py"))
            result = run()
            self.assertEqual(result.returncode, 1)
            self.assertIn("Missing conventional runner", result.stdout)
            self.assertIn("1 of 2 step(s) passed", result.stdout)
            runner.with_name("disabled.py").rename(runner)
            runner.write_text("print('expected discovery failure')\nraise SystemExit(7)\n", encoding="utf-8")
            result = run()
            self.assertEqual(result.returncode, 1)
            self.assertIn("expected discovery failure", result.stdout)
            self.assertIn("FAIL (exit 7)", result.stdout)
            runner.write_text("print('first ran')\n", encoding="utf-8")

            dependent = suite("actions", "example-dependent", dependency="example-one")
            checks = suite("conventions", "example-checks")
            (checks / "scripts/tests/test-repository.py").write_text("print('inert')\n", encoding="utf-8")
            subprocess.run(["git", "-C", str(root), "init", "--quiet"], check=True, capture_output=True)
            subprocess.run(["git", "-C", str(root), "-c", "core.autocrlf=false", "add", "-A"], check=True, capture_output=True)
            subprocess.run(["git", "-C", str(root), "-c", "user.name=test", "-c", "user.email=test@example.invalid", "commit", "--quiet", "-m", "baseline"], check=True, capture_output=True)
            self.assertIn("Nothing changed", run().stdout)
            with (first / "SKILL.md").open("a", encoding="utf-8") as stream:
                stream.write("changed\n")
            result = run()
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertIn("Affected suites: 3 of 4", result.stdout)
            for name in ("example-one/", "example-dependent/", "example-checks/"):
                self.assertIn(name, result.stdout)
            self.assertNotIn("example-two/", result.stdout)
            self.assertIn("4 of 4 step(s) passed", run("--all").stdout)


if __name__ == "__main__":
    unittest.main()
