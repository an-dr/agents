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

    # Spec: the design approved, the plan the agent's, agent-verified
    # iterations, the result approved, then finish removes the state.
    def test_spec_with_handover(self) -> None:
        self.assert_pass("spec start", "start", "--flow", "Spec")
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
        self.assert_fail("spec has no scope gate", ("approve", "--gate", "scope-approved", "--note", "x"), "no approval gate")
        self.assert_pass("spec intake->design", "advance")
        self.assert_fail("spec design needs approval", ("advance",), "design-approved")
        self.assert_pass("spec add question", "add-question", "--text", "Which API?")
        self.assert_fail("questions block design", ("approve", "--gate", "design-approved", "--note", "ok"), "still open")
        self.assert_pass("spec answer", "answer-question", "--number", "1", "--answer", "REST")
        self.assert_pass("spec design approved", "approve", "--gate", "design-approved", "--note", "looks right")
        self.assert_pass("spec design->split", "advance")
        self.assert_fail("spec has no plan gate", ("approve", "--gate", "plan-approved", "--note", "x"), "no approval gate")
        self.assert_pass("spec add increment", "add-increment", "--scope", "core", "--description", "does X")
        self.assert_pass("spec split->branch", "advance")
        self.assert_fail("spec branch refuses base", ("advance",), "feature branch")
        self.git("switch", "-q", "-c", "feature/x")
        self.assert_pass("spec branch->docs", "advance")
        self.complete_increment()
        self.assert_fail("spec has no step gate", ("approve", "--gate", "step-approved", "--note", "x"), "no approval gate")
        self.assert_pass("spec verify->commit", "advance")
        (self.repo / "x.txt").write_text("x\n", encoding="utf-8")
        self.git("add", "x.txt", "tmp-agent-wip.json")
        self.git("commit", "-q", "-m", "feat: x")
        self.assert_pass("spec commit->summary", "advance")
        self.assert_fail("spec summary needs result", ("advance",), "result-approved")
        self.assert_fail("spec has no integrate gate", ("approve", "--gate", "integrate", "--note", "x"), "integrate")
        # A Spec-driven approval given at the retired FINAL_REVIEW still counts
        # once the state resumes at SUMMARY: a gate names its phase.
        legacy = self.state()
        legacy["flow"], legacy["phase"] = "SpecDriven", "FINAL_REVIEW"
        legacy["approvals"] = [{"gate": "accept", "phase": "FINAL_REVIEW", "note": "approve", "approvedAt": legacy["createdAt"]}]
        self.set_state(legacy)
        self.assert_pass("spec summary->handover on a migrated approval", "advance")
        # A state written at the retired INTEGRATE phase resumes at HANDOVER.
        legacy = self.state()
        legacy["phase"] = "INTEGRATE"
        self.set_state(legacy)
        result = self.run_workflow("status")
        if result.returncode != 0 or not re.search(r"HANDOVER \| current", self.output(result)):
            self.fail(f"INTEGRATE did not resume as HANDOVER: {self.output(result)}")
        self.assert_pass("spec finish", "finish")
        state = self.state()
        self.assertTrue(state.get("finishedAt"), "finish did not mark the state handed over.")
        self.assertEqual(state["baseBranch"], "main", "The handed-over state lost its base.")

    # Supervised: scope, design, plan, and each build iteration approved.
    def test_supervised(self) -> None:
        self.assert_pass("supervised start", "start", "--flow", "Supervised")
        self.set_intake()
        self.assert_fail("supervised intake needs gate", ("advance",), "scope-approved")
        self.assert_pass("supervised scope", "approve", "--gate", "scope-approved", "--note", "that's all")
        self.assert_pass("supervised intake->design", "advance")
        self.assert_fail("supervised design needs gate", ("advance",), "design-approved")
        self.assert_pass("supervised design", "approve", "--gate", "design-approved", "--note", "yes")
        self.assert_pass("supervised design->split", "advance")
        self.assert_pass("supervised add increment", "add-increment", "--scope", "core", "--description", "does X")
        self.assert_fail("supervised plan needs gate", ("advance",), "plan-approved")
        self.assert_pass("supervised plan", "approve", "--gate", "plan-approved", "--note", "go")
        self.assert_pass("supervised split->branch", "advance")
        self.git("switch", "-q", "-c", "feature/x")
        self.assert_pass("supervised branch->docs", "advance")
        self.complete_increment()
        self.assert_fail("supervised verify needs gate", ("advance",), "step-approved")

    # Retired flows: Detailed Auto and Spec-driven resume as Spec, Quick is refused.
    def test_retired_flows(self) -> None:
        self.assert_pass("legacy start", "start", "--flow", "Spec")
        state = self.state()
        for old in ("DetailedAuto", "SpecDriven"):
            state["flow"] = old
            state["approvals"] = [{"gate": "implement", "phase": "SPLIT", "note": "go", "approvedAt": state["createdAt"]}]
            self.set_state(state)
            result = self.run_workflow("status")
            if result.returncode != 0 or "Spec" not in self.output(result):
                self.fail(f"{old} did not resume as Spec: {self.output(result)}")
        state["flow"] = "Quick"
        self.set_state(state)
        self.assert_fail("quick refused", ("status",), "retired Quick flow")

    # Vibe: one gate, the result approved at HANDOVER, then finish.
    def test_vibe(self) -> None:
        self.git("switch", "-q", "-c", "dev")
        self.assert_pass("vibe start", "start", "--flow", "Vibe")
        state = self.state()
        if state["phase"] != "BUILD" or state["baseBranch"] != "dev":
            self.fail(f"Vibe did not start at BUILD from dev: {state['phase']} {state['baseBranch']}")
        self.git("switch", "-q", "-c", "feature/x")
        self.assert_pass("vibe handoff goal", "set-handoff", "--handoff-field", "goal", "--items", "Make X")
        self.assert_pass("vibe handoff next", "set-handoff", "--handoff-field", "next", "--items", "one | two")
        self.assert_fail("vibe has no design gate", ("approve", "--gate", "design-approved", "--note", "x"), "only gate is result-approved")
        self.assert_fail("vibe result only at handover", ("approve", "--gate", "result-approved", "--note", "x"), "only gate is result-approved")
        self.assert_fail("vibe has no increments", ("add-increment", "--scope", "a", "--description", "b"), "no requests or increments")
        self.assert_pass("vibe build->verify", "advance")
        self.assert_pass("vibe verify->commit", "advance")
        self.assert_pass("vibe redo", "return-to-build")
        for number in range(1, 4):
            self.assert_pass(f"vibe advance {number}", "advance")
        self.assert_fail("vibe handover is last", ("advance",), "HANDOVER is the last stage")
        self.assert_fail("vibe finish needs approval", ("finish",), "approve the built result")
        self.assert_pass("vibe result approved", "approve", "--gate", "result-approved", "--note", "ran it, fine")
        state = self.state()
        self.assertEqual(state["featureBranch"], "feature/x", f"Vibe did not record its branch: {state['featureBranch']}")
        self.assertEqual(len(state["handoff"]["next"]), 2, "The handoff list was not stored.")
        page = (self.repo / "tmp-agent-progress.html").read_text(encoding="utf-8")
        if "HANDOVER" not in page or "integrates onto <b>dev</b>" not in page:
            self.fail("Vibe page lacks its stages or base.")
        self.assert_fail("vibe does not switch", ("switch-flow", "--flow", "Supervised"), "Vibe does not switch")
        self.assert_pass("vibe finish", "finish")
        state = self.state()
        self.assertTrue(state.get("finishedAt"), "Vibe finish did not mark the state handed over.")
        self.assertFalse((self.repo / "tmp-agent-progress.html").exists(), "finish left the progress page behind.")
        self.assertEqual(state["baseBranch"], "dev", "The handed-over state lost its base.")
        self.assert_pass("vibe redo after handover", "return-to-build")
        self.assertIsNone(self.state().get("finishedAt"), "A redo did not reopen the work.")
        self.assertIn("Returned from HANDOVER to BUILD.", json.dumps(self.state()["history"]))

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
