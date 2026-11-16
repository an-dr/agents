"""Run the controller through each flow's gates in a throwaway repository."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CONTROLLER = Path(__file__).resolve().parents[1] / "workflow.py"
WIP_DATA_SKILL = Path(__file__).resolve().parents[3] / "an-dr-ai-use-wip-data"


class FlowTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp(prefix="wf-test-"))
        self.addCleanup(shutil.rmtree, self.repo, ignore_errors=True)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.email", "test@example.invalid")
        self.git("config", "user.name", "Test")
        (self.repo / "README.md").write_text("test\n", encoding="utf-8")
        self.git("add", "README.md")
        self.git("commit", "-q", "-m", "chore: initial")

    def git(self, *arguments: str) -> str:
        result = subprocess.run(["git", *arguments], cwd=self.repo, capture_output=True, text=True, check=False)
        return result.stdout.strip()

    def run_workflow(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(CONTROLLER), *arguments, "--wip-data-skill", str(WIP_DATA_SKILL)],
            cwd=self.repo,
            capture_output=True,
            text=True,
            check=False,
        )

    def output(self, result: subprocess.CompletedProcess[str]) -> str:
        return result.stdout + result.stderr

    def assert_pass(self, name: str, *arguments: str) -> None:
        result = self.run_workflow(*arguments)
        self.assertEqual(result.returncode, 0, f"{name} failed: {self.output(result)}")

    def assert_fail(self, name: str, arguments: tuple[str, ...], pattern: str) -> None:
        result = self.run_workflow(*arguments)
        self.assertNotEqual(result.returncode, 0, f"{name} should have failed.")
        self.assertRegex(self.output(result), pattern, f"{name} failed for the wrong reason: {self.output(result)}")

    # The test inspects and edits the state file as the user would see it.
    def state(self) -> dict:
        data = json.loads((self.repo / "tmp-agent-wip.json").read_text(encoding="utf-8-sig"))
        return data["sections"]["workflow"]

    def set_state(self, state: dict) -> None:
        path = self.repo / "tmp-agent-wip.json"
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        data["sections"]["workflow"] = state
        path.write_text(json.dumps(data, indent=2), encoding="utf-8")

    def set_intake(self) -> None:
        self.assert_pass("add-request", "add-request", "--text", "Make X")
        for field in ("goal", "constraints", "done", "outOfScope"):
            self.assert_pass(f"set {field}", "set-requirement", "--field", field, "--value", f"{field} text")

    def complete_increment(self) -> None:
        self.assert_pass("docs->build", "advance")
        self.assert_pass("build->verify", "advance")

    # Spec-driven: no intake gate, implement at SPLIT, agent-verified increments,
    # accept at FINAL_REVIEW, then finish hands the branch over with its state.
    def test_spec_driven_with_handover(self) -> None:
        self.assert_pass("spec start", "start", "--flow", "SpecDriven")
        self.assertTrue((self.repo / "tmp-agent-progress.html").is_file(), "Progress page was not rendered at start.")
        self.assertEqual(
            self.git("status", "--porcelain", "--", "tmp-agent-progress.html"),
            "",
            "Progress page is not excluded from git.",
        )
        self.assertTrue((self.repo / "tmp-agent-wip.json").is_file(), "State is not in tmp-agent-wip.json.")
        self.assertFalse((self.repo / ".progress").exists(), "A .progress folder was created.")
        page = (self.repo / "tmp-agent-progress.html").read_text(encoding="utf-8")
        self.assertIn('class="stages"', page, "Progress page has no stage table.")
        self.set_intake()
        self.assert_fail(
            "spec refuses intake gate",
            ("approve", "--gate", "intake", "--note", "x"),
            "records its own intake",
        )
        self.assert_pass("spec intake->design", "advance")
        self.assert_pass("spec design->split", "advance")
        self.assert_pass("spec add increment", "add-increment", "--scope", "core", "--description", "does X")
        self.assert_fail("spec split needs implement", ("advance",), "implement")
        self.assert_pass("spec implement", "approve", "--gate", "implement", "--note", "implement")
        self.assert_pass("spec split->branch", "advance")
        self.assert_fail("spec branch refuses base", ("advance",), "feature branch")
        self.git("switch", "-q", "-c", "spec/x")
        self.assert_pass("spec branch->docs", "advance")
        self.complete_increment()
        self.assert_fail("spec refuses verify gate", ("approve", "--gate", "verify", "--note", "x"), "records its own")
        self.assert_pass("spec verify->commit", "advance")
        (self.repo / "x.txt").write_text("x\n", encoding="utf-8")
        self.git("add", "x.txt", "tmp-agent-wip.json")
        self.git("commit", "-q", "-m", "feat: x")
        self.assert_pass("spec commit->summary", "advance")
        self.assert_pass("spec summary->final review", "advance")
        self.assert_fail("spec final review needs accept", ("advance",), "accept")
        self.assert_fail("spec has no integrate gate", ("approve", "--gate", "integrate", "--note", "x"), "integrate")
        self.assert_pass("spec accept", "approve", "--gate", "accept", "--note", "accept")
        self.assert_pass("spec final review->handover", "advance")
        # A state written at the retired INTEGRATE phase resumes at HANDOVER.
        legacy = self.state()
        legacy["phase"] = "INTEGRATE"
        self.set_state(legacy)
        result = self.run_workflow("status")
        if result.returncode != 0 or not re.search(r"HANDOVER \| current", self.output(result)):
            self.fail(f"INTEGRATE did not resume as HANDOVER: {self.output(result)}")
        self.assert_fail(
            "spec handover refuses new scope",
            ("add-increment", "--scope", "more", "--description", "y"),
            "handed over",
        )
        self.assert_pass("spec finish", "finish")
        state = self.state()
        self.assertTrue(state["finishedAt"], "finish did not mark the state handed over.")
        self.assertEqual(state["baseBranch"], "main", "The state lost its base branch.")
        result = self.run_workflow("status")
        self.assertRegex(self.output(result), "Handed over", f"Status does not say handed over: {self.output(result)}")

    # Spec-driven on the base branch when the user asks for it.
    def test_spec_driven_on_base(self) -> None:
        self.assert_pass("onbase start", "start", "--flow", "SpecDriven", "--on-base")
        self.set_intake()
        self.assert_pass("onbase intake->design", "advance")
        self.assert_pass("onbase design->split", "advance")
        self.assert_pass("onbase add increment", "add-increment", "--scope", "core", "--description", "does X")
        self.assert_pass("onbase implement", "approve", "--gate", "implement", "--note", "implement")
        self.assert_pass("onbase split->branch", "advance")
        self.assert_pass("onbase stays on main", "advance")

    # Supervised keeps every gate and never runs on the base branch.
    def test_supervised(self) -> None:
        self.assert_fail(
            "supervised refuses onbase",
            ("start", "--flow", "Supervised", "--on-base"),
            "only available for SpecDriven",
        )
        self.assert_pass("supervised start", "start", "--flow", "Supervised")
        self.set_intake()
        self.assert_fail("supervised intake needs gate", ("advance",), "intake")
        self.assert_pass("supervised intake", "approve", "--gate", "intake", "--note", "intake")
        self.assert_pass("supervised intake->design", "advance")
        self.assert_pass("supervised design->split", "advance")
        self.assert_pass("supervised add increment", "add-increment", "--scope", "core", "--description", "does X")
        self.assert_pass("supervised implement", "approve", "--gate", "implement", "--note", "implement")
        self.assert_pass("supervised split->branch", "advance")
        self.git("switch", "-q", "-c", "supervised/x")
        self.assert_pass("supervised branch->docs", "advance")
        self.complete_increment()
        self.assert_fail("supervised verify needs gate", ("advance",), "verify")

    # Retired flows: Detailed Auto resumes as Spec-driven, Quick is refused.
    def test_retired_flows(self) -> None:
        self.assert_pass("legacy start", "start", "--flow", "SpecDriven")
        state = self.state()
        state["flow"] = "DetailedAuto"
        self.set_state(state)
        result = self.run_workflow("status")
        if result.returncode != 0 or "Spec-driven" not in self.output(result):
            self.fail(f"DetailedAuto did not resume as Spec-driven: {self.output(result)}")
        state["flow"] = "Quick"
        self.set_state(state)
        self.assert_fail("quick refused", ("status",), "retired Quick flow")

    # Vibe: stages without gates, a handoff, and the base it started from.
    def test_vibe(self) -> None:
        self.git("switch", "-q", "-c", "dev")
        self.assert_pass("vibe start", "start", "--flow", "Vibe")
        state = self.state()
        if state["phase"] != "BUILD" or state["baseBranch"] != "dev":
            self.fail(f"Vibe did not start at BUILD from dev: {state['phase']} {state['baseBranch']}")
        self.git("switch", "-q", "-c", "vibe/x")
        self.assert_pass("vibe handoff goal", "set-handoff", "--handoff-field", "goal", "--items", "Make X")
        self.assert_pass("vibe handoff next", "set-handoff", "--handoff-field", "next", "--items", "one | two")
        self.assert_fail("vibe has no gates", ("approve", "--gate", "implement", "--note", "x"), "no gates")
        self.assert_fail("vibe has no increments", ("add-increment", "--scope", "a", "--description", "b"), "no gates")
        self.assert_pass("vibe build->verify", "advance")
        self.assert_pass("vibe verify->commit", "advance")
        self.assert_pass("vibe redo", "return-to-build")
        for number in range(1, 4):
            self.assert_pass(f"vibe advance {number}", "advance")
        self.assert_fail("vibe handover is last", ("advance",), "HANDOVER is the last stage")
        self.assert_pass("vibe finish", "finish")
        self.assertIn("finishedAt", self.state(), "Vibe finish did not mark the state handed over.")
        self.assert_pass("vibe redo after handover", "return-to-build")
        self.assertNotIn("finishedAt", self.state(), "A redo did not reopen the handed-over work.")
        self.assert_fail("vibe does not switch", ("switch-flow", "--flow", "Supervised"), "Vibe does not switch")
        state = self.state()
        self.assertEqual(state["featureBranch"], "vibe/x", f"Vibe did not record its branch: {state['featureBranch']}")
        self.assertEqual(self.git("config", "--get", "branch.vibe/x.an-dr-base"), "dev", "The base was not written to the branch config.")
        self.assertEqual(len(state["handoff"]["next"]), 2, "The handoff list was not stored.")
        page = (self.repo / "tmp-agent-progress.html").read_text(encoding="utf-8")
        if "HANDOVER" not in page or "integrates onto <b>dev</b>" not in page:
            self.fail("Vibe page lacks its stages or base.")

    # A state from before the move resumes from .progress/workflow.json.
    def test_legacy_progress_path(self) -> None:
        self.assert_pass("legacy path start", "start", "--flow", "Supervised")
        (self.repo / ".progress").mkdir()
        (self.repo / ".progress" / "workflow.json").write_text(json.dumps(self.state(), indent=2), encoding="utf-8")
        (self.repo / "tmp-agent-wip.json").unlink()
        (self.repo / ".progress" / "PROGRESS.md").write_text("old\n", encoding="utf-8")
        self.assert_pass("legacy path resumes", "add-question", "--text", "q")
        self.assertTrue((self.repo / "tmp-agent-wip.json").is_file(), "The legacy state was not moved into tmp-agent-wip.json.")
        self.assertFalse((self.repo / ".progress").exists(), "The legacy state was not moved into tmp-agent-wip.json.")
        self.assertEqual(len(self.state()["questions"]), 1, "The moved state lost its content.")


if __name__ == "__main__":
    unittest.main()
