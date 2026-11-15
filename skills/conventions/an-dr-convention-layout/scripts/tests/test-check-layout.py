"""Exercise every layout finding against disposable Git indexes."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "check-layout.py"


class LayoutTests(unittest.TestCase):
    def repository(self, root: Path, files: tuple[str, ...]) -> None:
        subprocess.run(["git", "-C", str(root), "init", "--quiet"], check=True, capture_output=True)
        for relative in files:
            file = root / relative
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text("x", encoding="utf-8")
        subprocess.run(["git", "-C", str(root), "add", "--all"], check=True, capture_output=True)

    def check(self, root: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run([sys.executable, str(SCRIPT), "--path", str(root)], capture_output=True, text=True, check=False)

    def test_clean_errors_and_warning_only(self) -> None:
        with tempfile.TemporaryDirectory(prefix="check-layout-") as temporary:
            parent = Path(temporary)
            clean = parent / "clean"
            clean.mkdir()
            self.repository(clean, ("README.md", "LICENSE", "docs/index.md", "apps/tool/Cargo.toml", "apps/tool/src/main.rs", "apps/suite/host/main.rs", "apps/suite/web/index.ts", "tests/unit/a.rs"))
            result = self.check(clean)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

            bad = parent / "bad"
            bad.mkdir()
            self.repository(bad, ("README.md", "doc/index.md", "example/a.c", ".artifacts/code-review/r.json", "code-review/r.html", "pkg/__pycache__/m.pyc", "apps/cross-wall/host/Cargo.toml", "apps/cross-wall/host/src/main.rs"))
            result = self.check(bad)
            self.assertEqual(result.returncode, 1)
            for expected in ("| warning | root-file | `LICENSE`", "`doc/`", "`example/`", "`.artifacts/`", "`code-review/`", "`pkg/__pycache__/`", "| error | empty-nesting | `apps/cross-wall/host/`"):
                self.assertIn(expected, result.stdout)
            self.assertNotIn("`.artifacts/code-review/`", result.stdout)

            warning = parent / "warning"
            warning.mkdir()
            self.repository(warning, ("README.md", "src/main.c"))
            result = self.check(warning)
            self.assertEqual(result.returncode, 0)
            self.assertIn("0 error(s), 1 warning(s).", result.stdout)


if __name__ == "__main__":
    unittest.main()
