"""Check that check-readme.py finds ADRs in docs/adr, the folder an-dr-convention-adr writes them to."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "check-readme.py"


class ReadmeAdrTests(unittest.TestCase):
    def test_docs_adr_is_recognised(self) -> None:
        with tempfile.TemporaryDirectory(prefix="check-readme-") as temporary:
            root = Path(temporary)
            (root / "docs" / "adr").mkdir(parents=True)
            (root / "docs" / "adr" / "ADR-001-a.md").write_text("# ADR-001: A\n", encoding="utf-8")
            (root / "README.md").write_text("# Sample\n\nA tool.\n", encoding="utf-8")
            # The Markdown format check is not under test; an empty folder makes check-readme skip it.
            markdown = root / "no-markdown-skill"
            result = subprocess.run(
                [sys.executable, str(CHECKER), "--path", str(root), "--markdown-skill", str(markdown)],
                capture_output=True,
                text=True,
                check=False,
            )
            output = result.stdout + result.stderr
            self.assertRegex(output, r"docs directory\s+yes, with ADRs")
            self.assertIn("module.adr", output)


if __name__ == "__main__":
    unittest.main()
