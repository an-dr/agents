"""Exercise artifact creation, collisions, publishing, and invalid inputs."""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parents[1]


def run(script: str, *arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([sys.executable, str(SCRIPTS / script), *arguments], capture_output=True, text=True, encoding="utf-8", check=False)


class ArtifactPathTests(unittest.TestCase):
    def test_paths_collisions_and_latest_copies(self) -> None:
        with tempfile.TemporaryDirectory(prefix="artifact-layout-") as temporary:
            root = Path(temporary)
            command = ("json", "--kind", "code-review", "--stamp", "2026-11-01_14-32", "--repository-root", str(root))
            first = run("find-destination.py", *command)
            self.assertEqual(first.returncode, 0, first.stderr)
            path = Path(first.stdout.strip())
            self.assertEqual(path, root / ".tmp-ai-gen/code-review/code-review-2026-11-01_14-32.json")
            self.assertTrue((root / ".tmp-ai-gen/.gitignore").is_file())
            path.write_text("{}", encoding="utf-8")
            html = run("find-destination.py", "html", "--kind", "code-review", "--stamp", "2026-11-01_14-32", "--repository-root", str(root))
            self.assertEqual(html.returncode, 0, html.stderr)
            Path(html.stdout.strip()).write_text("<html></html>", encoding="utf-8")

            auto = run("find-destination.py", "json", "--kind", "code-review", "--repository-root", str(root))
            self.assertEqual(auto.returncode, 0, auto.stderr)
            Path(auto.stdout.strip()).write_text("{}", encoding="utf-8")
            again = run("find-destination.py", "json", "--kind", "code-review", "--repository-root", str(root))
            self.assertEqual(again.returncode, 0, again.stderr)
            self.assertNotEqual(again.stdout.strip(), auto.stdout.strip())
            if re.sub(r"-2\.json$", ".json", again.stdout.strip()) == auto.stdout.strip():
                self.assertRegex(again.stdout.strip(), r"_\d{2}-\d{2}-2\.json$")

            copies = run("pin-latest.py", str(path))
            self.assertEqual(copies.returncode, 0, copies.stderr)
            self.assertEqual(len(copies.stdout.splitlines()), 2)
            self.assertTrue((root / ".tmp-ai-gen/code-review-latest.html").is_file())
            for arguments in (
                ("html", "--kind", "Code_Review", "--repository-root", str(root)),
                ("HTML", "--kind", "code-review", "--repository-root", str(root)),
                ("html", "--kind", "code-review", "--stamp", "2026-11-01-A", "--repository-root", str(root)),
            ):
                with self.subTest(arguments=arguments):
                    self.assertNotEqual(run("find-destination.py", *arguments).returncode, 0)
            self.assertNotEqual(run("pin-latest.py", str(root / "elsewhere.html")).returncode, 0)

    def test_internal_kind_goes_under_internal_and_has_no_latest(self) -> None:
        with tempfile.TemporaryDirectory(prefix="artifact-layout-") as temporary:
            root = Path(temporary)
            result = run("find-destination.py", "questions.json", "--kind", "ui-session", "--internal", "--stamp", "2026-11-22_14-05", "--repository-root", str(root))
            self.assertEqual(result.returncode, 0, result.stderr)
            path = Path(result.stdout.strip())
            self.assertEqual(path, root / ".tmp-ai-gen/.internal/ui-session/ui-session-2026-11-22_14-05.questions.json")
            path.write_text("{}", encoding="utf-8")
            self.assertNotEqual(run("pin-latest.py", str(path)).returncode, 0)
            self.assertNotEqual(run("find-destination.py", "html", "--name", "x", "--internal", "--repository-root", str(root)).returncode, 0)

    def test_other_kind_takes_a_name_and_has_no_latest(self) -> None:
        with tempfile.TemporaryDirectory(prefix="artifact-layout-") as temporary:
            root = Path(temporary)
            command = ("html", "--name", "plugin-comparison", "--repository-root", str(root))
            first = run("find-destination.py", *command, "--stamp", "2026-11-22_14-05")
            self.assertEqual(first.returncode, 0, first.stderr)
            path = Path(first.stdout.strip())
            self.assertEqual(path, root / ".tmp-ai-gen/other/2026-11-22_14-05-plugin-comparison.html")
            path.write_text("<html></html>", encoding="utf-8")
            auto = run("find-destination.py", *command)
            self.assertEqual(auto.returncode, 0, auto.stderr)
            self.assertRegex(Path(auto.stdout.strip()).name, r"^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}(?:-\d+)?-plugin-comparison\.html$")
            Path(auto.stdout.strip()).write_text("x", encoding="utf-8")
            again = run("find-destination.py", *command)
            self.assertNotEqual(again.stdout.strip(), auto.stdout.strip())
            for arguments in (
                ("html", "--repository-root", str(root)),
                ("html", "--name", "Bad Name", "--repository-root", str(root)),
                ("html", "--kind", "code-review", "--name", "x", "--repository-root", str(root)),
            ):
                with self.subTest(arguments=arguments):
                    self.assertNotEqual(run("find-destination.py", *arguments).returncode, 0)
            self.assertNotEqual(run("pin-latest.py", str(path)).returncode, 0)


if __name__ == "__main__":
    unittest.main()
