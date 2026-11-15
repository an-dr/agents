"""Check graph groups, edges, missing declarations, and Markdown updates."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "build-dependencies.py"


class DependencyGraphTests(unittest.TestCase):
    def test_graph_and_markdown(self) -> None:
        with tempfile.TemporaryDirectory(prefix="build-dependencies-") as temporary:
            root = Path(temporary)

            def skill(category: str, name: str, declared: str | None) -> None:
                path = root / "skills" / category / name / "SKILL.md"
                path.parent.mkdir(parents=True, exist_ok=True)
                metadata = f"metadata:\n  an-dr.dependencies: {declared}\n" if declared else ""
                path.write_text(f"---\nname: {name}\ndescription: Test. Use when testing.\n{metadata}---\n\n# {name}\n", encoding="utf-8")

            def invoke(*arguments: str) -> subprocess.CompletedProcess[str]:
                return subprocess.run([sys.executable, str(SCRIPT), "--root", str(root), *arguments], capture_output=True, text=True, check=False)

            skill("actions", "alpha", "beta gamma")
            skill("actions", "beta", "none")
            skill("concepts", "gamma", "PROHIBITED")
            skill("_repo", "delta", None)
            result = invoke()
            self.assertEqual(result.returncode, 0, result.stderr)
            for expected in ("alpha --> beta & gamma", 'subgraph g_repo["Repo"]', "class delta undeclared", "Skills without an-dr.dependencies (1)"):
                self.assertIn(expected, result.stdout)
            self.assertEqual(invoke("--check").returncode, 1)

            readme = root / "README.md"
            readme.write_text("# Title\n\n<!-- skill-dependencies begin -->\nold\n<!-- skill-dependencies end -->\n\nTail.\n", encoding="utf-8")
            result = invoke("--markdown", str(readme))
            self.assertEqual(result.returncode, 0, result.stderr)
            text = readme.read_text(encoding="utf-8")
            self.assertIn("alpha --> beta & gamma", text)
            self.assertNotIn("old", text)
            self.assertIn("Tail.", text)
            self.assertEqual(invoke("--markdown", str(readme), "--check").returncode, 1)
            skill("_repo", "delta", "beta")
            self.assertIn("is stale", invoke("--markdown", str(readme), "--check").stdout)
            self.assertEqual(invoke("--markdown", str(readme)).returncode, 0)
            self.assertIn("is current", invoke("--markdown", str(readme), "--check").stdout)
            self.assertIn("delta --> beta", readme.read_text(encoding="utf-8"))
            readme.write_text("no markers\n", encoding="utf-8")
            self.assertNotEqual(invoke("--markdown", str(readme)).returncode, 0)


if __name__ == "__main__":
    unittest.main()
