"""Render tmp-agent-progress.html at the repository root from tmp-agent-wip.json."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path


STYLE = """<style>
:root { color-scheme: light dark; --accent: #c2185b; --ok: #2e7d32; --line: color-mix(in srgb, currentColor 20%, transparent); }
body { font: 15px/1.5 system-ui, sans-serif; margin: 0; }
main { max-width: 56rem; margin: 0 auto; padding: 1rem 1.25rem 3rem; }
h1 { margin: .2rem 0 .6rem; } h2 { font-size: 1rem; margin: 1.4rem 0 .3rem; text-transform: uppercase; letter-spacing: .05em; opacity: .8; }
.muted { opacity: .6; } .scroll { overflow-x: auto; }
.stages th { text-align: left; font-size: .8rem; opacity: .7; padding: .3rem .5rem; } .stages td:first-child { width: 1.5rem; }
.stages .done { opacity: .5; } .stages .phase th { opacity: 1; font-size: .9rem; padding-top: .7rem; border-bottom: 2px solid var(--line); } .stages .now td { color: var(--accent); font-weight: 700; }
.you { border-left: 4px solid var(--accent); padding: .4rem .8rem; font-weight: 600; }
table { border-collapse: collapse; width: 100%; } td { border-bottom: 1px solid var(--line); padding: .3rem .5rem; vertical-align: top; }
tr.completed { opacity: .6; } tr.in_progress td, tr.verified td { font-weight: 600; }
li.open { color: var(--accent); } li.closed { opacity: .7; } .log { list-style: none; padding: 0; }
</style>"""

FLOW_LABELS = {"SpecDriven": "Spec", "DetailedAuto": "Spec", "Detailed": "Supervised"}

# The common path every flow walks; each stage belongs to one step of it.
PHASES = {
    "INTAKE": "Request",
    "DESIGN": "Design",
    "SPLIT": "Plan",
    "BRANCH": "Build iterations",
    "DOCS": "Build iterations",
    "BUILD": "Build iterations",
    "VERIFY": "Build iterations",
    "COMMIT": "Build iterations",
    "SUMMARY": "Approval",
    "HANDOVER": "Handover",
}

# What each stage is for, so the table reads without the policy at hand.
STAGES = {
    "Vibe": {
        "BUILD": "Implement",
        "VERIFY": "Verify",
        "COMMIT": "Commit",
        "HANDOVER": "You approve the result by running it, then the branch is handed over",
    },
    "Spec": {
        "INTAKE": "Your request",
        "DESIGN": "Design; you approve it",
        "SPLIT": "Plan of build iterations",
        "BRANCH": "Work branch created",
        "DOCS": "Implement: documentation",
        "BUILD": "Implement: code",
        "VERIFY": "Verify",
        "COMMIT": "Commit",
        "SUMMARY": "You approve the result",
        "HANDOVER": "Branch ready to integrate",
    },
    "Supervised": {
        "INTAKE": "Your request; you approve the scope",
        "DESIGN": "You explain the design; you approve it",
        "SPLIT": "Plan of build iterations; you approve it",
        "BRANCH": "Work branch created",
        "DOCS": "Implement: documentation",
        "BUILD": "Implement: code",
        "VERIFY": "Verify; you approve the iteration",
        "COMMIT": "Commit",
        "SUMMARY": "You approve the result",
        "HANDOVER": "Branch ready to integrate",
    },
}

HANDOFF_SECTIONS = (
    ("next", "Next"),
    ("done", "Done"),
    ("openQuestions", "Open questions"),
    ("decisions", "Decisions and why"),
    ("files", "Files in play"),
)


class RenderError(Exception):
    """A refusal reported to the caller as an exit code 1."""


def run_git(*arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(["git", *arguments], capture_output=True, text=True, check=False)


def html_encode(text: object) -> str:
    if text is None:
        return ""
    return (
        str(text)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&#39;")
    )


def list_html(items: list[str], empty: str = "none") -> str:
    if not items:
        return f'<p class="muted">{empty}</p>'
    return "<ul>" + "".join(f"<li>{html_encode(item)}</li>" for item in items) + "</ul>"


def local_clock(value: object) -> str:
    return datetime.fromisoformat(str(value).replace("Z", "+00:00")).astimezone().strftime("%H:%M")


def read_state(root: Path, wip: Path) -> object:
    result = subprocess.run(
        [sys.executable, str(wip), "get", "--section", "workflow", "--reader", "an-dr-dev-follow-workflow", "--root", str(root)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise RenderError(result.stderr.strip() or f"wip.py exited {result.returncode}.")
    output = result.stdout.strip()
    return None if output == "null" else json.loads(output)


def handoff_field(handoff: dict, name: str) -> list[str]:
    if name not in handoff or handoff[name] is None:
        return []
    value = handoff[name]
    return value if isinstance(value, list) else [value]


def render(root: Path, skill_folder: Path) -> None:
    page = root / "tmp-agent-progress.html"
    wip = skill_folder / "scripts" / "wip.py"
    if not wip.is_file():
        raise RenderError(f"-WipDataSkill must be an-dr-ai-use-wip-data's folder; '{wip}' does not exist.")
    state = read_state(root, wip)

    if state is None:
        page.unlink(missing_ok=True)
        print("No workflow state; tmp-agent-progress.html removed.")
        return
    if not isinstance(state, dict):
        raise RenderError("The workflow section of tmp-agent-wip.json must be a JSON object.")
    # A handed-over flow is closed: nothing waits on the user, and the state
    # travels only to name the base for integration.
    if state.get("finishedAt"):
        page.unlink(missing_ok=True)
        print("Workflow handed over; tmp-agent-progress.html removed.")
        return

    branch = run_git("-C", str(root), "branch", "--show-current").stdout.strip()
    flow = state.get("flow")
    flow_label = FLOW_LABELS.get(flow, flow)
    stages = STAGES.get(flow_label, STAGES["Spec"])
    names = list(stages)
    phase = state.get("phase")
    index = names.index(phase) if phase in names else -1

    body: list[str] = []
    rows = []
    group = None
    for position, name in enumerate(names):
        if PHASES.get(name) != group:
            group = PHASES.get(name)
            rows.append(f'<tr class="phase"><th colspan="3">{html_encode(group)}</th></tr>')
        if position < index:
            css, mark = "done", "✔"
        elif position == index:
            css, mark = "now", "▶"
        else:
            css, mark = "todo", ""
        rows.append(f'<tr class="{css}"><td>{mark}</td><td>{name}</td><td>{html_encode(stages[name])}</td></tr>')
    title = f"{flow_label} · {phase}"
    body.append(f'<h1>{html_encode(flow_label)} <span class="muted">·</span> {phase}</h1>')
    body.append(
        f'<p class="muted">Branch {html_encode(branch)} → integrates onto '
        f'<b>{html_encode(state.get("baseBranch"))}</b></p>'
    )
    body.append(
        '<section><h2>Stages</h2><table class="stages"><tr><th></th><th>Stage</th>'
        f'<th>What happens</th></tr>{"".join(rows)}</table></section>'
    )

    open_questions = [question for question in state.get("questions") or [] if question.get("status") == "open"]
    if open_questions:
        waiting = f"{len(open_questions)} open question(s) need your answer."
    elif phase == "INTAKE" and flow_label == "Supervised":
        waiting = "Waiting for you to approve the scope."
    elif phase == "DESIGN":
        waiting = "Waiting for you to approve the design."
    elif phase == "SPLIT" and flow_label == "Supervised":
        waiting = "Waiting for you to approve the plan."
    elif phase == "VERIFY" and flow_label == "Supervised":
        waiting = "Waiting for you to approve this build iteration."
    elif phase == "SUMMARY" or (phase == "HANDOVER" and flow_label == "Vibe"):
        waiting = "Waiting for you to approve the result."
    else:
        waiting = None
    if waiting:
        body.append(f'<p class="you">▶ {html_encode(waiting)}</p>')

    handoff = state.get("handoff") if isinstance(state.get("handoff"), dict) else {}
    requirements = state.get("requirements") if isinstance(state.get("requirements"), dict) else {}
    if requirements.get("goal"):
        goal = requirements["goal"]
    elif handoff_field(handoff, "goal"):
        goal = " ".join(str(item) for item in handoff_field(handoff, "goal"))
    else:
        goal = "not yet defined"
    goal_html = f"<p>{html_encode(goal)}</p>"
    if requirements.get("done"):
        goal_html += f"<p><b>Done when:</b> {html_encode(requirements['done'])}</p>"
    body.append(f"<section><h2>Goal</h2>{goal_html}</section>")

    increments = state.get("increments") or []
    if increments:
        increment_rows = []
        for item in increments:
            mark = {"completed": "✔", "planned": "·"}.get(item.get("status"), "▶")
            increment_rows.append(
                f'<tr class="{item.get("status")}"><td>{mark}</td><td>{item.get("number")}</td>'
                f'<td>{html_encode(item.get("scope"))}</td><td>{html_encode(item.get("description"))}</td></tr>'
            )
        body.append(
            f'<section><h2>Increments</h2><div class="scroll"><table>{"".join(increment_rows)}</table></div></section>'
        )

    questions = state.get("questions") or []
    if questions:
        items = [f'<li class="open"><b>?</b> {html_encode(item.get("text"))}</li>' for item in open_questions]
        items += [
            f'<li class="closed">{html_encode(item.get("text"))} → {html_encode(item.get("answer"))}</li>'
            for item in questions
            if item.get("status") != "open"
        ]
        body.append(f'<section><h2>Questions</h2><ul>{"".join(items)}</ul></section>')

    for name, heading in HANDOFF_SECTIONS:
        items = handoff_field(handoff, name)
        if items:
            body.append(f"<section><h2>{heading}</h2>{list_html(items)}</section>")

    notebook = list(state.get("notebook") or [])[-8:]
    if notebook:
        notebook.reverse()
        notes = []
        for entry in notebook:
            link = f" (corrects #{entry['corrects']})" if entry.get("corrects") else ""
            link += f" (tests #{entry['tests']})" if entry.get("tests") else ""
            notes.append(
                f'<li><span class="muted">#{entry.get("number")} {html_encode(entry.get("kind"))}</span> '
                f'{html_encode(entry.get("text"))}{html_encode(link)}</li>'
            )
        body.append(f'<section><h2>Notebook</h2><ul class="log">{"".join(notes)}</ul></section>')

    recent = list(state.get("history") or [])[-8:]
    recent.reverse()
    log = [
        f'<li><span class="muted">{local_clock(entry.get("at"))}</span> {html_encode(entry.get("detail"))}</li>'
        for entry in recent
    ]
    body.append(f'<section><h2>Recent steps</h2><ul class="log">{"".join(log)}</ul></section>')

    stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    document = (
        "<!DOCTYPE html>\n"
        '<html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f'<meta http-equiv="refresh" content="5"><title>{html_encode(title)}</title>\n'
        + STYLE
        + "</head>\n<body><main>\n"
        + "\n".join(body)
        + "\n"
        + f'<p class="muted">Rendered {stamp} · reloads every 5 s</p>\n'
        + "</main></body></html>\n"
    )
    page.write_text(document, encoding="utf-8")

    # Keep the page out of history without touching the host's .gitignore.
    exclude = run_git("-C", str(root), "rev-parse", "--git-path", "info/exclude").stdout.strip()
    exclude_path = Path(exclude)
    if not exclude_path.is_absolute():
        exclude_path = root / exclude_path
    exclude_path = Path(str(exclude_path).rstrip("\\/"))
    entry = "/tmp-agent-progress.html"
    if not exclude_path.is_file() or entry not in exclude_path.read_text(encoding="utf-8", errors="replace"):
        exclude_path.parent.mkdir(parents=True, exist_ok=True)
        if exclude_path.is_file():
            with exclude_path.open("a", encoding="utf-8", newline="") as stream:
                stream.write(entry + os.linesep)
        else:
            exclude_path.write_text(entry + os.linesep, encoding="utf-8", newline="")
    print(f"Rendered {page}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root", "-RepositoryRoot", type=Path)
    parser.add_argument("--wip-data-skill", "-WipDataSkill", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.repository_root:
            root = args.repository_root
        else:
            result = run_git("rev-parse", "--show-toplevel")
            if result.returncode != 0 or not result.stdout.strip():
                raise RenderError("Run inside a git repository or pass -RepositoryRoot.")
            root = Path(result.stdout.strip())
        render(root, args.wip_data_skill)
    except (OSError, ValueError, RenderError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
