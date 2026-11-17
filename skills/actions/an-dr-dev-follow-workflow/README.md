# an-dr-dev-follow-workflow

The workflow controller: it keeps every flow's state in one file, `tmp-agent-wip.json`, and enforces the common path and each flow's approvals, so the stage, approvals, questions, build iterations, and the handoff live in a file rather than in the agent's memory of the chat.

## When it runs

- You choose a flow for a task: **Vibe**, **Spec**, or **Supervised**.
- A repository already holds `tmp-agent-wip.json`; every response then starts from the controller's status table.
- Work moves to another machine, or the plan's build iterations need reordering.

## How it works

Every flow walks the common path described in the [root README](../../../README.md#-how-the-flows-work): Request → Design → Plan → build iterations (Implement → Verify → Commit) → Approval → Handover. The controller is one script, `scripts/workflow.py`. Each command reads the state, checks that the transition is legal — approval present, right branch, iteration committed, no open question before the design is approved — writes the new state, and refuses anything else, so the agent cannot skip an approval by forgetting it.

Whatever the agent cannot settle alone becomes a recorded question. It keeps exploring and brings the questions to you together.

## What you decide

| Flow       | You approve                                                       |
| ---------- | ----------------------------------------------------------------- |
| Vibe       | the result, by running it                                         |
| Spec       | the design, then the result                                       |
| Supervised | the scope, the design, the plan, each build iteration, the result |

You approve in your own words; the agent records them with the controller.

## What you get

- `tmp-agent-wip.json` at the repository root — the state, including the base branch the work returns to and the handoff; committed with the work branch so another machine can resume it.
- `tmp-agent-progress.html` at the repository root — a live page, grouped by the common path, with the current stage marked, what waits on you, build iterations, questions, the handoff, and recent steps. It never enters git, and `finish` removes it.
- At the end, a handed-over branch: commits regrouped, `tmp-` files stripped, and the state in one `DO-NOT-MERGE:` commit at the tip, ready to integrate when you ask.

## Related skills

- [an-dr-dev-integrate](../an-dr-dev-integrate/README.md) — integrates the handed-over branch when you ask.
- [an-dr-git-modify-history](../an-dr-git-modify-history/README.md) — every commit and its automatic push.
- [an-dr-convention-branch-name](../../conventions/an-dr-convention-branch-name/README.md) — how the work branch is named.
