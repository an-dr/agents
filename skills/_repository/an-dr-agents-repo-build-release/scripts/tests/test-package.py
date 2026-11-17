"""Check release contents, checksum, and tag validation."""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "package.py"


class PackageTests(unittest.TestCase):
    def test_public_content_and_tag(self) -> None:
        with tempfile.TemporaryDirectory(prefix="pkg-test-") as temporary:
            root = Path(temporary)
            for relative in ("AGENTS.md", "README.md", "LICENSE", "skills/README.md", "skills/actions/an-dr-x/SKILL.md", "skills/_repository/an-dr-agents-repo-y/SKILL.md", "docs/releases/1.2.3.md"):
                file = root / relative
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text(relative, encoding="utf-8")
            (root / "VERSION").write_text("1.2.3", encoding="utf-8")
            out = root / "out"

            def invoke(tag: str) -> subprocess.CompletedProcess[str]:
                return subprocess.run([sys.executable, str(SCRIPT), "--root", str(root), "--out-directory", str(out), "--tag", tag], capture_output=True, text=True, check=False)

            result = invoke("v1.2.3")
            self.assertEqual(result.returncode, 0, result.stderr)
            archive_path = Path(result.stdout.strip())
            self.assertTrue(archive_path.is_file())
            with zipfile.ZipFile(archive_path) as archive:
                names = archive.namelist()
            for required in ("AGENTS.md", "README.md", "VERSION", "LICENSE", "skills/actions/an-dr-x/SKILL.md"):
                self.assertIn(f"agents-1.2.3/{required}", names)
            self.assertFalse(any("_repository" in name for name in names))
            self.assertRegex((out / "SHA256SUMS").read_text(encoding="utf-8"), r"^[0-9a-f]{64}  agents-1\.2\.3\.zip$")
            pre = invoke("v1.2.3-pre.2")
            self.assertEqual(pre.returncode, 0, pre.stderr)
            self.assertEqual(Path(pre.stdout.strip()).name, "agents-1.2.3-pre.2.zip")
            for bad in ("v1.2.3-pre.0", "v1.2.3-pre2", "v1.2.3-rc.1"):
                self.assertNotEqual(invoke(bad).returncode, 0, bad)
            wrong = invoke("v9.9.9")
            self.assertNotEqual(wrong.returncode, 0)
            self.assertIn("does not match VERSION", wrong.stderr)


if __name__ == "__main__":
    unittest.main()
