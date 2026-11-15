---
name: an-dr-dev-follow-workflow
description: Run, resume, and enforce the repository's workflow state for Vibe, Spec-driven, or Supervised, with the gates of the latter two. Use when the user selects a flow, tmp-agent-wip.json exists, the handoff needs rewriting, state must move to another machine, or increments must be inserted or reordered.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "3.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-use-user-interface an-dr-ai-use-wip-data an-dr-convention-adr an-dr-dev-analyze-changes an-dr-dev-debug an-dr-dev-design an-dr-dev-implement-code an-dr-dev-implement-pipeline an-dr-dev-integrate an-dr-dev-review an-dr-dev-test an-dr-dev-write-documentation an-dr-dev-write-readme an-dr-dev-write-specification an-dr-git-modify-history
---

# Workflow controller

Owns: the `workflow` section of `tmp-agent-wip.json`, every flow's state, kept through `an-dr-ai-use-wip-data`, and the phase transitions and approval gates of Spec-driven and Supervised, through `scripts/workflow.py`.

## Start or resume

1. From the host root, locate this skill relative to the active `AGENTS.md`; `<script>` below is `<skill>/scripts/workflow.py`. Every command also takes `--wip-data-skill <an-dr-ai-use-wip-data>`, left out of the examples below.
2. While `tmp-agent-wip.json` holds a `workflow` section, run `status` first in every response and present its Markdown table verbatim, as its `user-output: verbatim` markers require. That table, not the JSON file or the conversation, decides phase, gates, and open questions.
3. Command fails → quote the command and its error and stop; never reconstruct state from the file.
4. No active state → start as soon as the flow is chosen; only `--flow` is required; pass whichever of the four facts the request makes plain, and `INTAKE` collects the rest.

```sh
python <skill>/scripts/workflow.py status
python <skill>/scripts/workflow.py start --flow Vibe
python <skill>/scripts/workflow.py start --flow Supervised [--goal '<problem>']
python <skill>/scripts/workflow.py start --flow SpecDriven [--on-base] [--goal '<problem>']
```

- Start on the branch the work returns to: it is recorded as `baseBranch`, which `an-dr-dev-integrate` lands onto.
- `Vibe`: stages `BUILD`, `VERIFY`, `DELIVER`, `LAND`, with no gates, requests, or increments; `advance` moves on, `return-to-build` is redo, and `an-dr-dev-integrate` performs `LAND` and removes the state.
- `SpecDriven`: design discussion closed by `implement`, then the agent runs every increment unattended to `FINAL_REVIEW`, where the user reviews docs, change report, and pull request and gives `accept`; `HANDOVER` then cleans the branch for integration. `--on-base` only when the user asks for it on the base branch: no work branch, no pull request.
- `Supervised`: closed intake, approved plan, work branch, docs before each increment's code, per-increment user verification, a summary the user accepts, then `HANDOVER`.
- No flow integrates by itself: it ends with a handed-over branch. Landing it is `an-dr-dev-integrate`, run only when the user asks.
- Each flow only when the user selects it; never inferred from a request for autonomy or end-only involvement.
- State written by retired flows resumes as their successor (`Detailed` → `Supervised`, `DetailedAuto` → `SpecDriven`); a `Quick` state is refused with instructions.

## Plan and work by phase

- `INTAKE`, `DESIGN`, and `SPLIT` are read-only: no edit, branch, or commit. In them, read [references/planning.md](references/planning.md) before recording requests or presenting the plan.
- From `DOCS` on, read [references/phases.md](references/phases.md) for the skills and checks of the current phase.

## Operate the workflow

```sh
python <script> add-question --text '<what the user must decide>'
python <script> answer-question --number 2 --answer '<the user's answer>'
python <script> dismiss-question --number 3 --answer '<why it stopped mattering>'
python <script> approve --gate intake --note '<the user's own words>'
python <script> advance
python <script> return-to-build
python <script> switch-flow --flow Supervised
python <script> add-increment --at 2 --scope '<scope>' --description '<result>'
python <script> move-increment --number 4 --to 2
python <script> defer-increment --to 6
python <script> remove-increment --number 7
python <script> set-handoff --handoff-field next --items '<entry> | <entry>'
python <script> finish
```

- Every state-changing command also renders `tmp-agent-progress.html` at the host root through `scripts/render-progress-page.py`: the stage table with the current stage marked, then what waits on the user, increments, questions, the handoff, and recent steps. It adds the page to `.git/info/exclude` and removes it when no state exists.
- `set-handoff` replaces one handoff field whole: `goal` takes one text, `done`, `next`, `openQuestions`, `decisions`, and `files` take entries separated by ` | ` or newlines.
- `advance` rejects missing approvals or increments, wrong branches, uncommitted increments, and illegal transitions.
- `return-to-build` records a failed verification, invalidates the increment's verification approval, and resumes BUILD with the same increment identity; in Vibe it is redo, from `VERIFY`, `DELIVER`, or `LAND`.
- Before `add-increment`, `move-increment`, `defer-increment`, or `remove-increment`, read [references/increments.md](references/increments.md).
- Before proposing or running `switch-flow`, read [references/switch-flow.md](references/switch-flow.md).

## Gates

| Gate        | Where                                            | Meaning                                        |
| ----------- | ------------------------------------------------ | ---------------------------------------------- |
| `intake`    | Supervised `INTAKE`                              | the user says the request list is complete     |
| `implement` | `SPLIT` in both flows                            | the user has seen the plan and says build it   |
| `verify`    | Supervised `VERIFY`, once per increment          | the user accepts that increment's verification |
| `accept`    | Supervised `SUMMARY`, Spec-driven `FINAL_REVIEW` | the user accepts the delivered branch          |

- The controller names the gate it expects. Spec-driven refuses `intake` and `verify`; it settles intake in the design discussion and records verification itself. `DESIGN` has no gate.
- Ask each user gate as an `an-dr-ai-use-user-interface` confirmation, never a closing line like "reply implement": show the plan, increment, or summary first, then, in the same message, one approving option and one asking for a change.
- `--note` is the chosen label plus any notes the user added; a widget choice counts as their own words; any other answer leaves the gate closed.
- A request recorded after `intake` approval drops it; the user closes the longer list again.
- The controller records approval evidence and never supplies it, in Spec-driven too, where review, tests, doc checks, and clean commits still run between `implement` and final review.

## Questions

- `add-question` records, at any phase, what the agent cannot settle alone, instead of interrupting.
- `answer-question` and `dismiss-question` both require `--answer`; a dismissal records why it stopped mattering.
- Ask accumulated questions as one `an-dr-ai-use-user-interface` round; pass each echoed decision as `--answer`.
- `approve --gate implement` is refused while any question is open, listing the offenders.

## Share and finish

- Before committing progress state, moving work to another machine, or running `finish`, read [references/finish.md](references/finish.md).
