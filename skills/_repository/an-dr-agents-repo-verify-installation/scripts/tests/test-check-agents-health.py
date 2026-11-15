"""Check the repository layer, the workflow state, and the verdict of check-agents-health.py."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


HEALTH = Path(__file__).resolve().parents[1] / "check-agents-health.py"
NULL_STUB = """
import json
import sys
print(json.dumps({}))
"""
WORKFLOW_STUB = """
import json
import sys
values = {"flow": "vibe", "phase": "build"}
field = sys.argv[sys.argv.index("--field") + 1]
print(json.dumps(values.get(field)))
"""


def stub_wip(folder: Path, source: str) -> Path:
    (folder / "scripts").mkdir(parents=True)
    (folder / "scripts/wip.py").write_text(source, encoding="utf-8")
    return folder


def check(*arguments: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(HEALTH), *arguments],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


class RepositoryLayerTests(unittest.TestCase):
    def test_repository_without_opt_in(self) -> None:
        with tempfile.TemporaryDirectory(prefix="health-") as temporary:
            root = Path(temporary)
            wip = stub_wip(root / "wip-skill", NULL_STUB)
            repo = root / "repo"
            repo.mkdir()
            result = check("--repository-path", str(repo), "--wip-data-skill", str(wip), "--skip-install-check")
            self.assertEqual(result.returncode, 1)
            self.assertIn("no root AGENTS.md or CLAUDE.md", result.stdout)
            self.assertIn("| verdict | pickup | info | this repository does not opt in", result.stdout)

    def test_workflow_state_reaches_the_verdict(self) -> None:
        with tempfile.TemporaryDirectory(prefix="health-") as temporary:
            root = Path(temporary)
            wip = stub_wip(root / "wip-skill", WORKFLOW_STUB)
            repo = root / "repo"
            (repo / "agents/skills/category/skill").mkdir(parents=True)
            (repo / "AGENTS.md").write_text("# Policy\nRead agents/AGENTS.md\n\n## Commit scopes\n- suite\n", encoding="utf-8")
            (repo / "CLAUDE.md").write_text("@AGENTS.md\n", encoding="utf-8")
            (repo / "agents/AGENTS.md").write_text("# Rules\n", encoding="utf-8")
            (repo / "agents/skills/category/skill/SKILL.md").write_text("---\nname: skill\n---\n", encoding="utf-8")
            (repo / "tmp-agent-wip.json").write_text('{"schemaVersion": 1, "sections": {"workflow": {}}}', encoding="utf-8")
            result = check("--repository-path", str(repo), "--wip-data-skill", str(wip), "--skip-install-check")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("tmp-agent-wip.json holds a workflow (vibe at build)", result.stdout)
            self.assertIn("| verdict | pickup | pass |", result.stdout)

    def test_stale_main_is_a_warning(self) -> None:
        with tempfile.TemporaryDirectory(prefix="health-") as temporary:
            root = Path(temporary)
            wip = stub_wip(root / "wip-skill", NULL_STUB)
            clone = root / "clone"
            clone.mkdir()
            env = {**os.environ, "GIT_COMMITTER_DATE": "2020-01-01T00:00:00", "GIT_AUTHOR_DATE": "2020-01-01T00:00:00"}
            for command in (["init", "--quiet", "-b", "main"], ["commit", "--quiet", "--allow-empty", "-m", "base"],
                            ["switch", "--quiet", "-c", "dev"], ["commit", "--quiet", "--allow-empty", "-m", "change"]):
                subprocess.run(
                    ["git", "-C", str(clone), "-c", "user.name=test", "-c", "user.email=test@example.invalid", *command],
                    check=True, capture_output=True, env=env,
                )
            result = check(
                "--repository-path", str(root), "--wip-data-skill", str(wip),
                "--agents-root", str(clone), "--skip-install-check",
            )
            self.assertIn("main staleness", result.stdout)
            self.assertIn("is stale", result.stdout)

    def test_missing_wip_script_names_the_parameter(self) -> None:
        with tempfile.TemporaryDirectory(prefix="health-") as temporary:
            result = check(
                "--repository-path", temporary, "--wip-data-skill", temporary, "--skip-install-check"
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("--wip-data-skill", result.stderr)


if __name__ == "__main__":
    unittest.main()
