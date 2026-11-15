"""Check Git-discoverable Markdown, including new files, without scanning ignored artifacts."""

from __future__ import annotations

import runpy
import subprocess
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check-markdown.py"
ROOT = Path(__file__).resolve().parents[5]


class RepositoryMarkdownTests(unittest.TestCase):
    def test_repository_markdown(self) -> None:
        if not (ROOT / "skills" / "README.md").is_file():
            self.skipTest("Not in the source skill repository")
        listed = subprocess.run(
            ["git", "-C", str(ROOT), "-c", "core.quotepath=false", "ls-files", "--cached", "--others", "--exclude-standard", "--", "*.md"],
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(listed.returncode, 0, "Could not discover repository Markdown files.")
        files = sorted({line for line in listed.stdout.splitlines() if line})
        paths = [ROOT / name for name in files if (ROOT / name).is_file()]
        self.assertTrue(paths, "No repository Markdown files discovered.")
        # The file list is too long for one command line, so the checker is loaded and run here.
        find = runpy.run_path(str(CHECKER))["violations"]
        problems: list[str] = []
        for path in paths:
            found = find(path)
            if found:
                details = "; ".join(f"line {line} {rule} {detail}" for _, rule, line, detail in found)
                problems.append(f"{path}: {details}")
        self.assertEqual(problems, [], "Repository Markdown check failed.")


if __name__ == "__main__":
    unittest.main()
