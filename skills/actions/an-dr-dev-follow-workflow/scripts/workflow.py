"""Run, resume, and enforce the repository's workflow state."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


OWNER = "an-dr-dev-follow-workflow"
COMMANDS = (
    "start",
    "status",
    "advance",
    "return-to-build",
    "switch-flow",
    "approve",
    "add-increment",
    "move-increment",
    "defer-increment",
    "remove-increment",
    "add-request",
    "remove-request",
    "set-requirement",
    "add-question",
    "answer-question",
    "dismiss-question",
    "set-handoff",
    "finish",
)
FLOWS = ("Vibe", "SpecDriven", "Supervised")
GATES = ("intake", "implement", "verify", "accept")
REQUIREMENT_FIELDS = ("goal", "constraints", "done", "outOfScope")
HANDOFF_FIELDS = ("goal", "done", "next", "openQuestions", "decisions", "files")
INCREMENT_STATUSES = ("planned", "in_progress", "verified", "completed")
ACTIVE_PHASES = ("DOCS", "BUILD", "VERIFY", "COMMIT")
# Files the controller rewrites on every command, which a clean-tree check
# ignores: every tmp- or .tmp- path, the state file and the page among them.
TMP_EXCLUDE = (
    ":(exclude,glob)**/tmp-*",
    ":(exclude,glob)**/tmp-*/**",
    ":(exclude,glob)**/.tmp-*",
    ":(exclude,glob)**/.tmp-*/**",
)


class WorkflowError(Exception):
    """A refusal or a broken state, reported to the caller as an exit code 1."""


@dataclass
class Context:
    wip: "Wip"
    root: Path
    workflow_path: Path


def run_git(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *arguments], capture_output=True, text=True, check=False)


def repository_root() -> Path:
    result = run_git("rev-parse", "--show-toplevel")
    if result.returncode != 0 or not result.stdout.strip():
        raise WorkflowError("Run the workflow controller inside a Git repository.")
    return Path(result.stdout.strip())


def current_branch() -> str:
    return run_git("branch", "--show-current").stdout.strip()


def git_head() -> str:
    result = run_git("rev-parse", "HEAD")
    if result.returncode != 0:
        raise WorkflowError("Unable to read the current Git commit.")
    return result.stdout.strip()


def work_tree_changes() -> list[str]:
    result = run_git("status", "--porcelain", "--", ".", *TMP_EXCLUDE)
    return [line for line in result.stdout.splitlines() if line]


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f") + "0Z"


def is_blank(value: object) -> bool:
    return value is None or not str(value).strip()


def as_int(value: object) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def assert_timestamp(value: object, name: str) -> None:
    if isinstance(value, datetime):
        return
    try:
        datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        raise WorkflowError(f"Workflow state contains an invalid '{name}' timestamp.") from None


class Wip:
    """an-dr-ai-use-wip-data's public script, reached through its folder."""

    def __init__(self, folder: Path | str) -> None:
        self.folder = Path(folder)
        self.script = self.folder / "scripts" / "wip.py"
        if not self.script.is_file():
            raise WorkflowError(f"-WipDataSkill must be an-dr-ai-use-wip-data's folder; '{self.script}' does not exist.")

    def call(self, *arguments: str) -> str:
        result = subprocess.run([sys.executable, str(self.script), *arguments], capture_output=True, text=True, check=False)
        if result.returncode != 0:
            raise WorkflowError(result.stderr.strip() or f"wip.py exited {result.returncode}.")
        return result.stdout.strip()

    def get(self, root: Path) -> object:
        output = self.call("get", "--section", "workflow", "--reader", OWNER, "--root", str(root))
        return None if output == "null" else json.loads(output)

    def set(self, root: Path, value: object) -> None:
        descriptor, temporary = tempfile.mkstemp(prefix="agents-workflow-", suffix=".json")
        try:
            with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as stream:
                json.dump(value, stream, ensure_ascii=False, indent=2)
            self.call("set", "--section", "workflow", "--owner", OWNER, "--json-path", temporary, "--root", str(root))
        finally:
            Path(temporary).unlink(missing_ok=True)

    def remove(self, root: Path) -> None:
        self.call("remove", "--section", "workflow", "--owner", OWNER, "--root", str(root))

    def path(self, root: Path) -> Path:
        return Path(self.call("path", "--root", str(root)))


class WorkflowLock:
    """One operation per repository, held on a lock file the OS releases."""

    def __init__(self, root: Path) -> None:
        digest = hashlib.sha256(str(root).lower().encode("utf-8")).hexdigest()
        self.path = Path(tempfile.gettempdir()) / f"agents-workflow-{digest}.lock"
        self.stream = os.fdopen(os.open(self.path, os.O_RDWR | os.O_CREAT, 0o600), "r+b")
        try:
            if os.name == "nt":
                import msvcrt

                msvcrt.locking(self.stream.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl

                fcntl.flock(self.stream.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            self.stream.close()
            raise WorkflowError("Another workflow controller operation is already running for this repository.") from None

    def release(self) -> None:
        self.stream.close()
        self.path.unlink(missing_ok=True)


def read_state(wip: Wip, root: Path) -> dict | None:
    value = wip.get(root)
    if value is None:
        return None
    if not isinstance(value, dict):
        raise WorkflowError("The workflow section of tmp-agent-wip.json must be a JSON object.")
    return value


# Before the state moved to the repository root it lived in .progress/; a
# workflow started then resumes from the new place.
def move_legacy_state(wip: Wip, root: Path) -> None:
    legacy_dir = root / ".progress"
    legacy = legacy_dir / "workflow.json"
    if legacy.is_file() and read_state(wip, root) is None:
        wip.set(root, json.loads(legacy.read_text(encoding="utf-8-sig")))
        legacy.unlink()
        (legacy_dir / "PROGRESS.md").unlink(missing_ok=True)
        if not any(legacy_dir.iterdir()):
            legacy_dir.rmdir()


def get_state(context: Context) -> dict:
    state = read_state(context.wip, context.root)
    if state is None:
        raise WorkflowError(f"No active workflow exists in '{context.workflow_path}'.")
    # Retired flows resume under the flow that replaced them: Detailed became
    # Supervised unchanged, and Detailed Auto became Spec-driven, whose phases
    # it already had. Quick has no successor with the same phases, so a Quick
    # state is refused rather than reshaped into something nobody approved.
    if state.get("flow") == "Detailed":
        state["flow"] = "Supervised"
    if state.get("flow") == "DetailedAuto":
        state["flow"] = "SpecDriven"
    if state.get("flow") == "Quick":
        raise WorkflowError(
            "This workflow uses the retired Quick flow. Commit its work and delete tmp-agent-wip.json, "
            "then start Spec-driven or Supervised, or finish it with an older controller."
        )
    state.setdefault("onBase", False)
    # Phases that no longer exist collapse into the one that replaced them.
    if state.get("phase") in ("MR", "MERGE_READY", "INTEGRATE_READY"):
        state["phase"] = "SUMMARY"
    # INTEGRATE landed the branch from inside the flow; the flow now ends at
    # HANDOVER, and landing is the separate an-dr-dev-integrate skill.
    if state.get("phase") in ("MERGE", "INTEGRATE"):
        state["phase"] = "HANDOVER"
    # START collected nothing; INTAKE collects the request list. A workflow
    # written before the rename resumes at the phase that replaced it, and its
    # requirements -- mandatory back then -- already satisfy the INTAKE exit.
    was_start = state.get("phase") == "START"
    if was_start:
        state["phase"] = "INTAKE"
    state.setdefault("questions", [])
    state.setdefault("requests", [])
    state.setdefault("handoff", {})
    state.setdefault("finishedAt", None)
    # A workflow that stopped in START has no request list and INTAKE will not
    # release an empty one, so its goal becomes the first request. Later phases
    # are left alone: they never return to INTAKE, and an invented request would
    # only mislead the reconciliation at SUMMARY.
    goal = (state.get("requirements") or {}).get("goal")
    if was_start and not state.get("requests") and goal:
        state["requests"] = [{"id": uuid.uuid4().hex, "number": 1, "text": str(goal)}]
    # Approvals under retired gate names are dropped rather than remapped: the
    # gates they authorized no longer exist, so the user re-authorizes under the
    # current ones. The history entries keep the record of what was approved.
    # `integrate` was given at the same review `accept` is given at now.
    approvals = state.get("approvals") or []
    for approval in approvals:
        if approval.get("gate") == "integrate":
            approval["gate"] = "accept"
    state["approvals"] = [approval for approval in approvals if approval.get("gate") in GATES]
    assert_state(state)
    return state


def workflow_phases(flow: str) -> list[str]:
    # Vibe has no gates; its stages only show where the work is.
    if flow == "Vibe":
        return ["BUILD", "VERIFY", "DELIVER", "LAND"]
    if flow == "Supervised":
        return ["INTAKE", "DESIGN", "SPLIT", "BRANCH", "DOCS", "BUILD", "VERIFY", "COMMIT", "SUMMARY", "HANDOVER"]
    return [
        "INTAKE",
        "DESIGN",
        "SPLIT",
        "BRANCH",
        "DOCS",
        "BUILD",
        "VERIFY",
        "COMMIT",
        "SUMMARY",
        "FINAL_REVIEW",
        "HANDOVER",
    ]


def assert_state(state: dict) -> None:
    if state.get("schemaVersion") != 1:
        raise WorkflowError(f"Unsupported workflow schema version '{state.get('schemaVersion')}'.")
    flow = state.get("flow")
    if flow not in FLOWS:
        raise WorkflowError(f"Unsupported workflow flow '{flow}'.")
    phase = state.get("phase")
    if phase not in workflow_phases(flow):
        raise WorkflowError(f"Phase '{phase}' is invalid for flow '{flow}'.")
    for prop in ("baseBranch", "baseCommit", "createdAt", "updatedAt"):
        if is_blank(state.get(prop)):
            raise WorkflowError(f"Workflow state is missing '{prop}'.")
    # INTAKE is where the four facts are written, so it is the one phase allowed
    # to hold an incomplete set; every later phase reads them as settled.
    requirements = state.get("requirements") or {}
    if phase != "INTAKE" and flow != "Vibe":
        for prop in REQUIREMENT_FIELDS:
            if is_blank(requirements.get(prop)):
                raise WorkflowError(f"Workflow requirements are missing '{prop}'.")
    assert_timestamp(state.get("createdAt"), "createdAt")
    assert_timestamp(state.get("updatedAt"), "updatedAt")
    if run_git("cat-file", "-e", f"{state.get('baseCommit')}^{{commit}}").returncode != 0:
        raise WorkflowError(f"Workflow base commit '{state.get('baseCommit')}' does not exist in this repository.")
    # Vibe records stages and a handoff only; the increment, branch and gate
    # rules below belong to the gated flows.
    if flow == "Vibe":
        return

    increments = state.get("increments") or []
    seen_ids: set[str] = set()
    expected_number = 1
    last_rank = -1
    for increment in increments:
        identifier = increment.get("id")
        if is_blank(identifier) or identifier in seen_ids:
            raise WorkflowError(f"Workflow contains a missing or duplicate increment ID '{identifier}'.")
        seen_ids.add(identifier)
        if as_int(increment.get("number")) != expected_number:
            raise WorkflowError(f"Expected increment number {expected_number}, found '{increment.get('number')}'.")
        status = increment.get("status")
        if status not in INCREMENT_STATUSES:
            raise WorkflowError(f"Increment {expected_number} has invalid status '{status}'.")
        for prop in ("scope", "description"):
            if is_blank(increment.get(prop)):
                raise WorkflowError(f"Increment {expected_number} is missing '{prop}'.")
        rank = {"completed": 0, "in_progress": 1, "verified": 1, "planned": 2}[status]
        if rank < last_rank:
            raise WorkflowError("Increment statuses must remain ordered as completed, active, then planned.")
        last_rank = rank
        expected_number += 1

    active = [increment for increment in increments if increment.get("status") in ("in_progress", "verified")]
    current_identifier = state.get("currentIncrementId")
    if current_identifier:
        current = [increment for increment in increments if increment.get("id") == current_identifier]
        if len(current) != 1 or len(active) != 1:
            raise WorkflowError("currentIncrementId must identify the only active increment.")
        expected_status = "verified" if phase == "COMMIT" else "in_progress"
        if current[0].get("status") != expected_status or phase not in ACTIVE_PHASES:
            raise WorkflowError(f"Active increment status is inconsistent with phase '{phase}'.")
    elif active:
        raise WorkflowError("Workflow has an active increment without currentIncrementId.")
    if phase in ACTIVE_PHASES and not current_identifier:
        raise WorkflowError(f"Phase '{phase}' requires an active increment.")
    if phase == "COMMIT" and is_blank(state.get("commitBaseline")):
        raise WorkflowError("COMMIT phase requires commitBaseline.")
    if phase != "COMMIT" and state.get("commitBaseline"):
        raise WorkflowError(f"commitBaseline is only valid during COMMIT, not '{phase}'.")
    if phase in ("SUMMARY", "FINAL_REVIEW", "HANDOVER") and any(
        increment.get("status") != "completed" for increment in increments
    ):
        raise WorkflowError(f"Phase '{phase}' requires every increment to be completed.")
    if phase not in ("INTAKE", "DESIGN", "SPLIT", "BRANCH") and is_blank(state.get("featureBranch")):
        raise WorkflowError(f"Phase '{phase}' requires featureBranch.")

    expected_number = 1
    seen_request_ids: set[str] = set()
    for request in state.get("requests") or []:
        identifier = request.get("id")
        if is_blank(identifier) or identifier in seen_request_ids:
            raise WorkflowError(f"Workflow contains a missing or duplicate request ID '{identifier}'.")
        seen_request_ids.add(identifier)
        if as_int(request.get("number")) != expected_number:
            raise WorkflowError(f"Expected request number {expected_number}, found '{request.get('number')}'.")
        if is_blank(request.get("text")):
            raise WorkflowError(f"Request {expected_number} is missing its text.")
        expected_number += 1

    expected_number = 1
    seen_question_ids: set[str] = set()
    for question in state.get("questions") or []:
        identifier = question.get("id")
        if is_blank(identifier) or identifier in seen_question_ids:
            raise WorkflowError(f"Workflow contains a missing or duplicate question ID '{identifier}'.")
        seen_question_ids.add(identifier)
        if as_int(question.get("number")) != expected_number:
            raise WorkflowError(f"Expected question number {expected_number}, found '{question.get('number')}'.")
        status = question.get("status")
        if status not in ("open", "answered", "dismissed"):
            raise WorkflowError(f"Question {expected_number} has invalid status '{status}'.")
        if is_blank(question.get("text")):
            raise WorkflowError(f"Question {expected_number} is missing its text.")
        if status != "open" and is_blank(question.get("answer")):
            raise WorkflowError(f"Question {expected_number} is {status} but records no answer.")
        expected_number += 1

    for approval in state.get("approvals") or []:
        if approval.get("gate") not in GATES or is_blank(approval.get("note")):
            raise WorkflowError("Workflow contains a malformed approval record.")
        assert_timestamp(approval.get("approvedAt"), "approval approvedAt")
    for entry in state.get("history") or []:
        if is_blank(entry.get("action")) or is_blank(entry.get("detail")):
            raise WorkflowError("Workflow contains a malformed history record.")
        assert_timestamp(entry.get("at"), "history at")


def assert_gated_flow(state: dict) -> None:
    if state.get("flow") == "Vibe":
        raise WorkflowError("Vibe has no gates, requests, or increments; it records its stages and its handoff only.")


def assert_workflow_branch(state: dict) -> None:
    if not state.get("featureBranch"):
        return
    branch = current_branch()
    if branch != state["featureBranch"]:
        raise WorkflowError(f"Workflow branch '{state['featureBranch']}' is required; current branch is '{branch}'.")


def add_history_entry(state: dict, action: str, detail: str) -> None:
    state["history"] = [*(state.get("history") or []), {"at": utc_now(), "action": action, "detail": detail}]


def update_progress_page(wip: Wip) -> None:
    """The browser page is derived from the same state; a failure never blocks a change."""
    script = Path(__file__).resolve().parent / "render-progress-page.py"
    try:
        result = subprocess.run(
            [sys.executable, str(script), "--repository-root", str(repository_root()), "--wip-data-skill", str(wip.folder)],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            raise WorkflowError(result.stderr.strip() or f"exit {result.returncode}")
    except (OSError, WorkflowError) as error:
        print(f"WARNING: Progress page not rendered: {error}", file=sys.stderr)


def save_state(context: Context, state: dict) -> None:
    state["updatedAt"] = utc_now()
    assert_state(state)
    context.wip.set(repository_root(), state)
    # Git-side tools find the base in the work branch's config, without the file.
    if state.get("featureBranch"):
        run_git("config", f"branch.{state['featureBranch']}.an-dr-base", str(state.get("baseBranch")))
    update_progress_page(context.wip)


def has_approval(state: dict, gate: str) -> bool:
    increment_id = state.get("currentIncrementId") if gate == "verify" else None
    return any(
        approval.get("gate") == gate
        and approval.get("phase") == state.get("phase")
        and (gate != "verify" or approval.get("incrementId") == increment_id)
        for approval in state.get("approvals") or []
    )


def assert_approval(state: dict, gate: str) -> None:
    if not has_approval(state, gate):
        raise WorkflowError(f"The '{gate}' approval is required before leaving {state.get('phase')}.")


def current_increment(state: dict) -> dict | None:
    identifier = state.get("currentIncrementId")
    if not identifier:
        return None
    for increment in state.get("increments") or []:
        if increment.get("id") == identifier:
            return increment
    return None


def set_increment_numbers(state: dict) -> None:
    for number, increment in enumerate(state.get("increments") or [], start=1):
        increment["number"] = number


def start_next_increment(state: dict, phase: str = "BUILD") -> None:
    # Where the increment starts. A fresh increment off BRANCH documents
    # before it builds; a deferral or removal resumes in BUILD, where the
    # increment it replaces already was.
    next_increment = next((item for item in state.get("increments") or [] if item.get("status") == "planned"), None)
    if next_increment is None:
        raise WorkflowError("No planned increment remains.")
    next_increment["status"] = "in_progress"
    state["currentIncrementId"] = next_increment["id"]
    state["phase"] = phase


def requirements_complete(state: dict) -> bool:
    """True when INTAKE has distilled all four facts the later phases read."""
    requirements = state.get("requirements") or {}
    return all(not is_blank(requirements.get(prop)) for prop in REQUIREMENT_FIELDS)


def open_questions(state: dict) -> list[dict]:
    return [question for question in state.get("questions") or [] if question.get("status") == "open"]


def resolve_question(state: dict, number: int | None) -> dict:
    """Returns the question at --number, or explains why it cannot be used."""
    if number is None:
        raise WorkflowError("-Number is required; it is the number shown in the question table.")
    questions = state.get("questions") or []
    if number < 1 or number > len(questions):
        raise WorkflowError(f"Question numbers run from 1 to {len(questions)}.")
    return questions[number - 1]


def assert_increment_committed(state: dict) -> None:
    if git_head() == state.get("commitBaseline"):
        raise WorkflowError("Commit the current increment, including tmp-agent-wip.json, before advancing.")
    if run_git("status", "--porcelain").stdout.strip():
        raise WorkflowError("The working tree must be clean before advancing from COMMIT.")


def show_status(state: dict, status: str = "active") -> None:
    flow_label = "Spec-driven" if state.get("flow") == "SpecDriven" else state.get("flow")
    if state.get("finishedAt"):
        status = "finished"
    increments = state.get("increments") or []
    increment = current_increment(state)
    increment_label = "—"
    if increment is not None:
        increment_label = f"{increment.get('number')}/{len(increments)} — {increment.get('scope')}"
    elif increments:
        increment_label = f"{len(increments)} total"

    lines = [
        "<!-- user-output: verbatim -->",
        "| Flow | Status | Increment |",
        "| --- | --- | --- |",
        f"| {flow_label} | {status} | {increment_label} |",
        "",
        "| Phase | Status |",
        "| --- | --- |",
    ]
    phases = workflow_phases(state.get("flow") or "")
    phase = state.get("phase")
    current_index = phases.index(phase) if phase in phases else -1
    for index, name in enumerate(phases):
        if status == "finished" or index < current_index:
            phase_status = "completed"
        elif index == current_index:
            phase_status = "current"
        else:
            phase_status = "pending"
        lines.append(f"| {name} | {phase_status} |")

    if increments:
        lines += ["", "| # | Increment | Status |", "| ---: | --- | --- |"]
    for item in increments:
        increment_text = f"{item.get('scope')} — {item.get('description')}".replace("|", "\\|")
        lines.append(f"| {item.get('number')} | {increment_text} | {item.get('status')} |")

    requests = state.get("requests") or []
    if requests:
        lines += ["", "| # | Request |", "| ---: | --- |"]
        for item in requests:
            request_text = str(item.get("text")).replace("|", "\\|")
            lines.append(f"| {item.get('number')} | {request_text} |")

    questions = state.get("questions") or []
    if questions:
        lines += ["", "| # | Question | Status | Answer |", "| ---: | --- | --- | --- |"]
        for item in questions:
            question_text = str(item.get("text")).replace("|", "\\|")
            answer_text = str(item.get("answer")).replace("|", "\\|") if item.get("answer") else "—"
            lines.append(f"| {item.get('number')} | {question_text} | {item.get('status')} | {answer_text} |")

    lines.append("")
    open_count = len(open_questions(state))
    if open_count > 0:
        lines.append(f"Open questions: {open_count} — the implement gate stays closed until each is answered or dismissed.")
    if status == "active" and phase == "INTAKE":
        requirements = state.get("requirements") or {}
        missing = [prop for prop in REQUIREMENT_FIELDS if is_blank(requirements.get(prop))]
        if missing:
            lines.append(f"Intake is open — keep recording requests. Still to distil: {', '.join(missing)}.")
        else:
            lines.append("Intake is open — keep recording requests until the user says the list is complete.")
    if state.get("finishedAt"):
        lines.append(
            f"Handed over: integrate onto '{state.get('baseBranch')}' with an-dr-dev-integrate when the user asks; "
            "it strips every tmp file."
        )
    requirements = state.get("requirements") or {}
    handoff = state.get("handoff") or {}
    if requirements.get("goal"):
        goal = requirements["goal"]
    elif "goal" in handoff:
        goal = handoff["goal"]
    else:
        goal = "(not yet defined)"
    lines.append(f"Base: {state.get('baseBranch')}")
    lines.append(f"Goal: {goal}")
    lines.append(f"Updated: {state.get('updatedAt')}")
    lines.append("<!-- /user-output -->")
    print("\n".join(lines))


def command_start(args: argparse.Namespace, context: Context) -> None:
    if read_state(context.wip, context.root) is not None:
        raise WorkflowError("An active workflow already exists. Resume it or finish it first.")
    # Only the flow is required: the four facts are what INTAKE produces, so
    # demanding them here would put requirement-gathering before the phase
    # that gathers it. Any that are known up front seed the state.
    if not args.flow:
        raise WorkflowError("-Flow is required when starting a workflow.")
    # Spec-driven may run on the base branch when the user asks for it;
    # Supervised always gets its own branch, since its per-increment review
    # happens in that branch's pull request.
    if args.on_base and args.flow != "SpecDriven":
        raise WorkflowError("-OnBase is only available for SpecDriven.")
    if args.flow == "Vibe" and work_tree_changes():
        raise WorkflowError("Vibe starts from a clean working tree; commit or stash first.")

    base_branch = current_branch()
    if is_blank(base_branch):
        raise WorkflowError("Workflows cannot start from a detached HEAD.")
    now = utc_now()
    state = {
        "schemaVersion": 1,
        "flow": args.flow,
        "phase": "BUILD" if args.flow == "Vibe" else "INTAKE",
        "baseBranch": base_branch,
        "baseCommit": git_head(),
        "featureBranch": None,
        "onBase": bool(args.on_base),
        "requirements": {
            "goal": args.goal,
            "constraints": args.constraints,
            "done": args.done,
            "outOfScope": args.out_of_scope,
        },
        "currentIncrementId": None,
        "commitBaseline": None,
        "increments": [],
        "requests": [],
        "questions": [],
        "approvals": [],
        "history": [],
        "handoff": {},
        "finishedAt": None,
        "createdAt": now,
        "updatedAt": now,
    }
    add_history_entry(state, "start", f"Started {args.flow} workflow.")
    save_state(context, state)
    show_status(state)


def command_status(args: argparse.Namespace, context: Context) -> None:
    show_status(get_state(context))


def command_approve(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_gated_flow(state)
    assert_workflow_branch(state)
    if not args.gate:
        raise WorkflowError("-Gate is required for approve.")
    if is_blank(args.note):
        raise WorkflowError("-Note is required to record the approval evidence.")
    # The user says intake once, when the request list is complete; implement
    # once, at the last phase before code is written; and accept once, at
    # the review of the finished branch. Spec-driven folds intake into the
    # design discussion and records its own per-increment verification, so
    # its user gates are implement and accept only. Landing the branch is not
    # a gate here: it is the separate an-dr-dev-integrate skill, run when the
    # user asks for it.
    phase = state.get("phase")
    if phase == "INTAKE":
        expected = "intake" if state.get("flow") == "Supervised" else None
    elif phase == "SPLIT":
        expected = "implement"
    elif phase == "VERIFY":
        expected = "verify" if state.get("flow") == "Supervised" else None
    elif phase == "SUMMARY":
        expected = "accept" if state.get("flow") == "Supervised" else None
    elif phase == "FINAL_REVIEW":
        expected = "accept"
    else:
        expected = None
    if state.get("flow") == "SpecDriven" and phase in ("INTAKE", "VERIFY", "SUMMARY"):
        raise WorkflowError(
            "Spec-driven records its own intake and verification; the user approves at SPLIT and FINAL_REVIEW."
        )
    if not expected:
        raise WorkflowError(f"{phase} has no approval gate. Advance instead.")
    if args.gate != expected:
        raise WorkflowError(f"Gate '{args.gate}' is not valid during {phase}. Expected '{expected}'.")
    if args.gate == "implement":
        waiting = open_questions(state)
        if waiting:
            detail = os.linesep.join(f"  {question.get('number')}  {question.get('text')}" for question in waiting)
            raise WorkflowError(
                f"{len(waiting)} question(s) are still open. Answer or dismiss each one "
                f"before authorizing implementation:{os.linesep}{detail}"
            )
    state["approvals"] = [
        *(state.get("approvals") or []),
        {
            "gate": args.gate,
            "phase": phase,
            "incrementId": state.get("currentIncrementId") if args.gate == "verify" else None,
            "note": args.note,
            "approvedAt": utc_now(),
        },
    ]
    add_history_entry(state, "approve", f"Approved {args.gate} during {phase}.")
    save_state(context, state)
    show_status(state)


# INTAKE accumulates what the user wants from this branch, one request at a
# time, across as many messages as it takes. The list stays in state for the
# whole workflow so SUMMARY can check the branch against what was asked for.
def command_add_request(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_gated_flow(state)
    assert_workflow_branch(state)
    if state.get("phase") != "INTAKE":
        raise WorkflowError(
            f"Requests are collected during INTAKE, not '{state.get('phase')}'. "
            "New scope after intake closes becomes an increment."
        )
    if is_blank(args.text):
        raise WorkflowError("-Text is required for add-request.")
    requests = list(state.get("requests") or [])
    request = {"id": uuid.uuid4().hex, "number": len(requests) + 1, "text": args.text}
    requests.append(request)
    state["requests"] = requests
    # The intake approval means "this list is complete"; a later request
    # makes it untrue, so the user closes the longer list again.
    state["approvals"] = [approval for approval in state.get("approvals") or [] if approval.get("gate") != "intake"]
    add_history_entry(state, "add-request", f"Recorded request {request['number']}: {args.text}")
    save_state(context, state)
    show_status(state)


def command_remove_request(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_gated_flow(state)
    assert_workflow_branch(state)
    if state.get("phase") != "INTAKE":
        raise WorkflowError(f"Requests can only be removed during INTAKE, not '{state.get('phase')}'.")
    if args.number is None:
        raise WorkflowError("-Number is required; it is the number shown in the request table.")
    requests = list(state.get("requests") or [])
    if args.number < 1 or args.number > len(requests):
        raise WorkflowError(f"Request numbers run from 1 to {len(requests)}.")
    request = requests.pop(args.number - 1)
    for number, item in enumerate(requests, start=1):
        item["number"] = number
    state["requests"] = requests
    state["approvals"] = [approval for approval in state.get("approvals") or [] if approval.get("gate") != "intake"]
    add_history_entry(state, "remove-request", f"Removed request {args.number}: {request.get('text')}")
    save_state(context, state)
    show_status(state)


# Distils the accumulated requests into the four facts every later phase
# reads. INTAKE cannot be left until all four are written.
def command_set_requirement(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_gated_flow(state)
    assert_workflow_branch(state)
    if is_blank(args.field):
        raise WorkflowError("-Field is required for set-requirement.")
    if is_blank(args.value):
        raise WorkflowError("-Value is required for set-requirement; never record an invented fact.")
    if not isinstance(state.get("requirements"), dict):
        state["requirements"] = {}
    state["requirements"][args.field] = args.value
    add_history_entry(state, "set-requirement", f"Set {args.field}.")
    save_state(context, state)
    show_status(state)


# INTAKE and DESIGN collect what the agent cannot decide alone instead of
# interrupting for each one; the implement gate is closed until none is open.
def command_add_question(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_workflow_branch(state)
    if is_blank(args.text):
        raise WorkflowError("-Text is required for add-question.")
    questions = list(state.get("questions") or [])
    question = {"id": uuid.uuid4().hex, "number": len(questions) + 1, "status": "open", "text": args.text, "answer": None}
    questions.append(question)
    state["questions"] = questions
    add_history_entry(state, "add-question", f"Recorded question {question['number']}: {args.text}")
    save_state(context, state)
    show_status(state)


def command_answer_question(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_workflow_branch(state)
    question = resolve_question(state, args.number)
    if is_blank(args.answer):
        raise WorkflowError("-Answer is required for answer-question.")
    question["status"] = "answered"
    question["answer"] = args.answer
    add_history_entry(state, "answer-question", f"Answered question {question.get('number')}.")
    save_state(context, state)
    show_status(state)


def command_dismiss_question(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_workflow_branch(state)
    question = resolve_question(state, args.number)
    if is_blank(args.answer):
        raise WorkflowError("-Answer is required for dismiss-question; record why it stopped mattering.")
    question["status"] = "dismissed"
    question["answer"] = args.answer
    add_history_entry(state, "dismiss-question", f"Dismissed question {question.get('number')}.")
    save_state(context, state)
    show_status(state)


def command_add_increment(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_gated_flow(state)
    assert_workflow_branch(state)
    if is_blank(args.scope) or is_blank(args.description):
        raise WorkflowError("-Scope and -Description are required for add-increment.")
    if state.get("phase") == "HANDOVER":
        raise WorkflowError("The accepted branch is being handed over. Start a follow-up workflow for new scope.")

    increments = list(state.get("increments") or [])
    position = args.at if args.at is not None else len(increments) + 1
    if position < 1 or position > len(increments) + 1:
        raise WorkflowError(f"-At must be between 1 and {len(increments) + 1}.")
    fixed_count = sum(1 for increment in increments if increment.get("status") != "planned")
    if position <= fixed_count:
        raise WorkflowError(f"Completed or active increments are fixed; insert at {fixed_count + 1} or later.")
    increment = {
        "id": uuid.uuid4().hex,
        "number": 0,
        "status": "planned",
        "scope": args.scope,
        "description": args.description,
    }
    increments.insert(position - 1, increment)
    state["increments"] = increments
    set_increment_numbers(state)
    if state.get("phase") in ("SUMMARY", "FINAL_REVIEW"):
        state["phase"] = "SPLIT"
        state["approvals"] = [
            approval for approval in state.get("approvals") or [] if approval.get("gate") not in ("implement", "accept")
        ]
    add_history_entry(state, "add-increment", f"Inserted increment {position}: {args.scope}")
    save_state(context, state)
    show_status(state)


def command_move_increment(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_gated_flow(state)
    assert_workflow_branch(state)
    if args.number is None or args.to is None:
        raise WorkflowError("-Number and -To are required for move-increment.")
    increments = list(state.get("increments") or [])
    if args.number < 1 or args.number > len(increments) or args.to < 1 or args.to > len(increments):
        raise WorkflowError(f"Increment positions must be between 1 and {len(increments)}.")
    increment = increments[args.number - 1]
    if increment.get("status") != "planned":
        raise WorkflowError("Only planned increments can be moved.")
    fixed_count = sum(1 for item in increments if item.get("status") != "planned")
    if args.to <= fixed_count:
        raise WorkflowError(f"Planned increments must remain after the first {fixed_count} fixed increment(s).")
    increments.pop(args.number - 1)
    increments.insert(args.to - 1, increment)
    state["increments"] = increments
    set_increment_numbers(state)
    add_history_entry(state, "move-increment", f"Moved increment {args.number} to {args.to}.")
    save_state(context, state)
    show_status(state)


# Reorders the active increment itself, which move-increment cannot: the
# state invariant keeps the active increment ahead of every planned one, so
# it can only change position by returning to 'planned' while the increment
# that replaces it becomes active in the same operation.
def command_defer_increment(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_gated_flow(state)
    assert_workflow_branch(state)
    if args.to is None:
        raise WorkflowError("-To is required for defer-increment.")
    if state.get("phase") != "BUILD":
        raise WorkflowError(f"defer-increment is only available in BUILD, not '{state.get('phase')}'.")
    current = current_increment(state)
    if current is None:
        raise WorkflowError("There is no active increment to defer.")
    # A clean tree is the evidence that nothing was built for this increment
    # yet. Work already committed under it cannot be detected here, so the
    # caller must not defer an increment whose commits are on the branch.
    # tmp files are excluded because the controller rewrites them on every
    # command, which would otherwise make this guard block itself.
    if work_tree_changes():
        raise WorkflowError("The working tree must be clean, apart from tmp files, to defer the active increment.")

    increments = list(state.get("increments") or [])
    position = next(index for index, item in enumerate(increments) if item is current)
    completed_count = sum(1 for item in increments if item.get("status") == "completed")
    if not any(item.get("status") == "planned" for item in increments):
        raise WorkflowError("No planned increment remains to take over from the deferred one.")
    # The increment taking over occupies the first post-completed slot, so a
    # deferral has to land at least one place behind it.
    earliest = completed_count + 2
    if args.to < earliest or args.to > len(increments):
        raise WorkflowError(f"The deferred increment must move to a position between {earliest} and {len(increments)}.")

    current["status"] = "planned"
    state["currentIncrementId"] = None
    increments.pop(position)
    increments.insert(args.to - 1, current)
    state["increments"] = increments
    start_next_increment(state)
    set_increment_numbers(state)
    taking = current_increment(state)
    add_history_entry(
        state,
        "defer-increment",
        f"Deferred '{current.get('scope')}' to position {args.to}; started '{taking.get('scope') if taking else None}'.",
    )
    save_state(context, state)
    show_status(state)


# Drops work the user has decided against. Completed increments are history
# and stay; only planned work, or an active increment nothing was built for,
# can leave the plan.
def command_remove_increment(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_gated_flow(state)
    assert_workflow_branch(state)
    if args.number is None:
        raise WorkflowError("-Number is required for remove-increment.")
    increments = list(state.get("increments") or [])
    if args.number < 1 or args.number > len(increments):
        raise WorkflowError(f"Increment positions must be between 1 and {len(increments)}.")
    increment = increments[args.number - 1]
    if increment.get("status") == "completed":
        raise WorkflowError("A completed increment is delivered history and cannot be removed.")
    is_active = increment.get("id") == state.get("currentIncrementId")
    if increment.get("status") != "planned" and not is_active:
        raise WorkflowError(f"Increment {args.number} is not planned and not the active increment.")
    if is_active:
        if state.get("phase") != "BUILD":
            raise WorkflowError(
                f"Removing the active increment is only available in BUILD, not '{state.get('phase')}'."
            )
        # Same evidence rule as defer-increment: a clean tree shows nothing
        # was built. Work already committed under it is invisible here.
        if work_tree_changes():
            raise WorkflowError("The working tree must be clean, apart from tmp files, to remove the active increment.")

    increments.pop(args.number - 1)
    state["increments"] = increments
    if is_active:
        state["currentIncrementId"] = None
        if any(item.get("status") == "planned" for item in increments):
            start_next_increment(state)
        else:
            # Nothing left to build: the branch is ready for its review.
            state["phase"] = "SUMMARY"
    set_increment_numbers(state)
    add_history_entry(state, "remove-increment", f"Removed increment {args.number}: {increment.get('scope')}.")
    save_state(context, state)
    show_status(state)


def command_advance(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_workflow_branch(state)
    previous_phase = state.get("phase")
    if state.get("flow") == "Vibe":
        phases = workflow_phases("Vibe")
        at = phases.index(previous_phase)
        if at >= len(phases) - 1:
            raise WorkflowError("LAND is the last stage: an-dr-dev-integrate lands the branch and removes this state.")
        # The work branch is the one the first stage was built on.
        branch = current_branch()
        if not state.get("featureBranch") and branch and branch != state.get("baseBranch"):
            state["featureBranch"] = branch
        state["phase"] = phases[at + 1]
        add_history_entry(state, "advance", f"Advanced from {previous_phase} to {state['phase']}.")
        save_state(context, state)
        show_status(state)
        return
    phase = previous_phase
    if phase == "INTAKE":
        if not state.get("requests"):
            raise WorkflowError("Record at least one request before leaving INTAKE.")
        if not requirements_complete(state):
            raise WorkflowError(
                "Distil the requests into goal, constraints, done, and outOfScope "
                "with set-requirement before leaving INTAKE."
            )
        # Spec-driven settles the request list inside its design
        # discussion, which the implement gate closes; Supervised asks
        # for the list to be closed on its own first.
        if state.get("flow") == "Supervised":
            assert_approval(state, "intake")
        state["phase"] = "DESIGN"
    elif phase == "DESIGN":
        state["phase"] = "SPLIT"
    elif phase == "SPLIT":
        if not state.get("increments"):
            raise WorkflowError("Add at least one increment before leaving SPLIT.")
        # Every flow buys its first written line with this approval,
        # Spec-driven included: the plan it will execute unattended is
        # exactly the plan the user should have seen.
        assert_approval(state, "implement")
        state["phase"] = "BRANCH"
    elif phase == "BRANCH":
        branch = current_branch()
        if is_blank(branch):
            raise WorkflowError("Switch from detached HEAD to a feature branch before leaving BRANCH.")
        if state.get("onBase") and branch != state.get("baseBranch"):
            raise WorkflowError(
                f"This Spec-driven workflow runs on '{state.get('baseBranch')}'; switch back to it before leaving BRANCH."
            )
        if not state.get("onBase") and branch == state.get("baseBranch"):
            raise WorkflowError("Create and switch to a feature branch before leaving BRANCH.")
        state["featureBranch"] = branch
        start_next_increment(state, "DOCS")
    elif phase == "DOCS":
        state["phase"] = "BUILD"
    elif phase == "BUILD":
        state["phase"] = "VERIFY"
    elif phase == "VERIFY":
        if state.get("flow") == "Supervised":
            assert_approval(state, "verify")
        current = current_increment(state)
        if current is not None:
            current["status"] = "verified"
        state["commitBaseline"] = git_head()
        state["phase"] = "COMMIT"
    elif phase == "COMMIT":
        assert_increment_committed(state)
        current = current_increment(state)
        if current is not None:
            current["status"] = "completed"
        state["commitBaseline"] = None
        if any(item.get("status") == "planned" for item in state.get("increments") or []):
            start_next_increment(state)
        else:
            state["currentIncrementId"] = None
            state["phase"] = "SUMMARY"
    elif phase == "SUMMARY":
        if state.get("flow") == "SpecDriven":
            state["phase"] = "FINAL_REVIEW"
        else:
            assert_approval(state, "accept")
            state["phase"] = "HANDOVER"
    elif phase == "FINAL_REVIEW":
        assert_approval(state, "accept")
        state["phase"] = "HANDOVER"
    else:
        raise WorkflowError(f"Phase {phase} cannot advance.")
    add_history_entry(state, "advance", f"Advanced from {previous_phase} to {state['phase']}.")
    save_state(context, state)
    show_status(state)


def command_return_to_build(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_workflow_branch(state)
    from_phases = ("VERIFY", "DELIVER", "LAND") if state.get("flow") == "Vibe" else ("VERIFY",)
    if state.get("phase") not in from_phases:
        raise WorkflowError(
            f"Workflow can only return to BUILD from {', '.join(from_phases)}; current phase is {state.get('phase')}."
        )
    state["phase"] = "BUILD"
    state["approvals"] = [
        approval
        for approval in state.get("approvals") or []
        if not (
            approval.get("gate") == "verify"
            and approval.get("incrementId") == state.get("currentIncrementId")
        )
    ]
    add_history_entry(state, "return-to-build", "Returned from VERIFY to BUILD.")
    save_state(context, state)
    show_status(state)


# A flow switch is a scope decision, not a phase transition: the work turned
# out larger or smaller than the flow started for it, which the request list
# usually reveals only once exploration is under way. Every flow-independent
# fact survives -- requests, questions with their answers, and the four
# requirements -- because those describe the work, not the process around
# it. It is legal only before anything is built, so no delivered work can be
# orphaned by it; after BRANCH, the branch is finished or abandoned instead.
def command_switch_flow(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_workflow_branch(state)
    if is_blank(args.flow):
        raise WorkflowError("-Flow is required for switch-flow.")
    if args.flow == state.get("flow"):
        raise WorkflowError(f"The workflow is already running as {args.flow}.")
    if "Vibe" in (args.flow, state.get("flow")):
        raise WorkflowError("Vibe does not switch: land or drop its branch, then start a gated flow.")
    if state.get("featureBranch"):
        raise WorkflowError(
            f"Cannot switch flow once BRANCH created '{state['featureBranch']}'; finish or abandon that branch first."
        )
    started = [increment for increment in state.get("increments") or [] if increment.get("status") != "planned"]
    if started:
        raise WorkflowError(
            f"Cannot switch flow once an increment has started; '{started[0].get('scope')}' is {started[0].get('status')}."
        )
    # The same evidence defer-increment relies on, for the same reason: a
    # clean tree is all the controller has to prove nothing was built under
    # the flow being left behind. tmp files are excluded because the
    # controller rewrites them on every command.
    if work_tree_changes():
        raise WorkflowError("The working tree must be clean, apart from tmp files, to switch flow.")

    previous_flow = state.get("flow")
    previous_phase = state.get("phase")
    dropped_increments = len(state.get("increments") or [])
    state["flow"] = args.flow
    # Back to INTAKE rather than to whichever phase the two flows share.
    # The flows do not collect the same gates -- Spec-driven never asks for
    # `intake`, Supervised cannot leave INTAKE without it -- so carrying a
    # phase across would credit the new flow with an approval nobody gave.
    # Reopening the request list is usually the point: the flow changed
    # because the user asked for something the old one was not sized for.
    state["phase"] = "INTAKE"
    state["approvals"] = []
    state["increments"] = []
    state["currentIncrementId"] = None
    state["commitBaseline"] = None
    add_history_entry(
        state,
        "switch-flow",
        f"Switched from {previous_flow}/{previous_phase} to {args.flow}/INTAKE; "
        f"dropped every approval and {dropped_increments} planned increment(s).",
    )
    save_state(context, state)
    show_status(state)


# The handoff a new session reads first: each field is rewritten whole at
# a checkpoint, never appended to, so it only ever holds the current state.
def command_set_handoff(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    if not args.handoff_field:
        raise WorkflowError("-HandoffField is required for set-handoff.")
    # One string per parameter, so a list arrives as one argument: entries
    # separated by ' | ' or by newlines, which some shells flatten on the way.
    entries: list[str] = []
    for item in args.items or []:
        for part in re.split(r"\s\|\s|\r?\n", item):
            if part.strip():
                entries.append(part.strip())
    if not isinstance(state.get("handoff"), dict):
        state["handoff"] = {}
    handoff = state["handoff"]
    handoff[args.handoff_field] = " ".join(entries) if args.handoff_field == "goal" else entries
    add_history_entry(state, "set-handoff", f"Updated the handoff's {args.handoff_field}.")
    save_state(context, state)
    show_status(state)


def command_finish(args: argparse.Namespace, context: Context) -> None:
    state = get_state(context)
    assert_workflow_branch(state)
    if state.get("flow") == "Vibe":
        raise WorkflowError("Vibe has no HANDOVER; an-dr-dev-integrate lands the branch and removes the state.")
    if state.get("phase") != "HANDOVER":
        raise WorkflowError(
            f"Workflow state can only be removed at HANDOVER; current state is {state.get('flow')}/{state.get('phase')}."
        )
    # On the base branch nothing integrates later, so the state goes now and
    # its deletion is committed. A work branch keeps it, marked handed over:
    # an-dr-dev-integrate reads the base from it, then strips every tmp file
    # from every commit before the branch lands.
    if state.get("onBase"):
        context.wip.remove(context.root)
        update_progress_page(context.wip)
        print("Workflow state removed. Commit the deletion of tmp-agent-wip.json.")
    else:
        state["finishedAt"] = utc_now()
        add_history_entry(state, "finish", "Handed over; waiting for integration.")
        save_state(context, state)
        print(
            f"Handed over. Commit tmp-agent-wip.json; an-dr-dev-integrate lands the branch onto "
            f"'{state.get('baseBranch')}' when the user asks."
        )
    show_status(state, "finished")


HANDLERS = {
    "start": command_start,
    "status": command_status,
    "advance": command_advance,
    "return-to-build": command_return_to_build,
    "switch-flow": command_switch_flow,
    "approve": command_approve,
    "add-increment": command_add_increment,
    "move-increment": command_move_increment,
    "defer-increment": command_defer_increment,
    "remove-increment": command_remove_increment,
    "add-request": command_add_request,
    "remove-request": command_remove_request,
    "set-requirement": command_set_requirement,
    "add-question": command_add_question,
    "answer-question": command_answer_question,
    "dismiss-question": command_dismiss_question,
    "set-handoff": command_set_handoff,
    "finish": command_finish,
}


def operate(args: argparse.Namespace) -> None:
    # The state is the `workflow` section of tmp-agent-wip.json, which only
    # an-dr-ai-use-wip-data's script reads and writes.
    wip = Wip(args.wip_data_skill)
    root = repository_root()
    workflow_path = wip.path(root)
    lock = None
    if args.command != "status":
        move_legacy_state(wip, root)
        lock = WorkflowLock(root)
    try:
        HANDLERS[args.command](args, Context(wip, root, workflow_path))
    finally:
        if lock is not None:
            lock.release()


def main() -> int:
    # The status table carries typographic marks; a console that cannot encode
    # them shows a placeholder instead of failing the command.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=COMMANDS)
    parser.add_argument("--flow", "-Flow", choices=FLOWS)
    parser.add_argument("--on-base", "-OnBase", action="store_true")
    parser.add_argument("--goal", "-Goal")
    parser.add_argument("--constraints", "-Constraints")
    parser.add_argument("--done", "-Done")
    parser.add_argument("--out-of-scope", "-OutOfScope")
    parser.add_argument("--field", "-Field", choices=REQUIREMENT_FIELDS)
    parser.add_argument("--value", "-Value")
    parser.add_argument("--gate", "-Gate", choices=GATES)
    parser.add_argument("--note", "-Note")
    parser.add_argument("--text", "-Text")
    parser.add_argument("--answer", "-Answer")
    parser.add_argument("--scope", "-Scope")
    parser.add_argument("--description", "-Description")
    parser.add_argument("--at", "-At", type=int)
    parser.add_argument("--number", "-Number", type=int)
    parser.add_argument("--to", "-To", type=int)
    parser.add_argument("--handoff-field", "-HandoffField", choices=HANDOFF_FIELDS)
    parser.add_argument("--items", "-Items", nargs="+")
    parser.add_argument("--wip-data-skill", "-WipDataSkill", type=Path, required=True)
    args = parser.parse_args()
    try:
        operate(args)
    except (OSError, ValueError, WorkflowError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
