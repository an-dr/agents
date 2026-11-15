"""Check that scan-project.py counts Rust files with inline test modules apart from test files."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCAN = Path(__file__).resolve().parents[1] / "scan-project.py"


class InlineTestCountTests(unittest.TestCase):
    def test_inline_test_modules(self) -> None:
        with tempfile.TemporaryDirectory(prefix="scan-inline-") as temporary:
            root = Path(temporary)
            (root / "src").mkdir()
            (root / "src/lib.rs").write_text(
                "pub fn one() -> u8 { 1 }\n\n#[cfg(test)]\nmod tests {\n    #[test]\n"
                "    fn works() { assert_eq!(super::one(), 1); }\n}",
                encoding="utf-8",
            )
            (root / "src/plain.rs").write_text("pub fn two() -> u8 { 2 }", encoding="utf-8")
            (root / "src/notes.py").write_text("# mentions #[test] but is not Rust", encoding="utf-8")
            report = root / "scan.json"
            result = subprocess.run(
                [sys.executable, str(SCAN), "--path", str(root), "--json", str(report)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            tests = json.loads(report.read_text(encoding="utf-8"))["tests"]
            self.assertEqual(tests["files"], 0)
            self.assertEqual(tests["inline"], 1)


if __name__ == "__main__":
    unittest.main()
