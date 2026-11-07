---
name: an-dr-dev-follow-workflow
description: Run, resume, and enforce the repository's gated Quick, Detailed, or Detailed Auto workflow; Direct work does not use it. Use when the user selects one of these flows, .progress/workflow.json exists, workflow state must move to another machine, or increments must be inserted or reordered.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.4.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message an-dr-convention-adr an-dr-dev-analyze-changes an-dr-dev-debug an-dr-dev-design an-dr-dev-implement-code an-dr-dev-implement-pipeline an-dr-dev-integrate an-dr-dev-review an-dr-dev-test an-dr-dev-write-documentation an-dr-dev-write-readme an-dr-dev-write-specification an-dr-git-commit
---

# Workflow controller

Owns: phase transitions and approval gates of Quick, Detailed, and Detailed Auto, through `scripts/workflow.ps1`. Direct has no controller state.

## Start or resume

1. From the host root, locate this skill relative to the active `AGENTS.md`; `<script>` below is `<skill>/scripts/workflow.ps1`.
2. While `.progress/workflow.json` exists, run `status` first in every response and present its Markdown table verbatim, as its `user-output: verbatim` markers require. That table, not the JSON file or the conversation, decides phase, gates, and open questions.
3. Command fails → quote the command and its error and stop; never reconstruct state from the file.
4. No active state → start as soon as the flow is chosen; only `-Flow` is required; pass whichever of the four facts the request makes plain, and `INTAKE` collects the rest.

```powershell
pwsh <skill>/scripts/workflow.ps1 status
pwsh <skill>/scripts/workflow.ps1 start -Flow Detailed [-Goal '<problem>']
```

- `Quick`: one docs/build/verify/commit pass with user decisions and verification.
- `Detailed`: increments, feature branch, docs before each increment's code, per-increment user verification, integration summary, explicit integration approval.
- `DetailedAuto`: Detailed's phases and intake, plan, and integration approvals; the agent performs and records per-increment verification until `FINAL_REVIEW`.
- `DetailedAuto` only when the user selects it; never inferred from a request for autonomy or end-only involvement.

## Plan and work by phase

- `INTAKE`, `DESIGN`, and `SPLIT` are read-only: no edit, branch, or commit. In them, read [references/planning.md](references/planning.md) before recording requests or presenting the plan.
- From `DOCS` on, read [references/phases.md](references/phases.md) for the skills and checks of the current phase.

## Operate the workflow

```powershell
pwsh <script> add-question -Text '<what the user must decide>'
pwsh <script> answer-question -Number 2 -Answer '<the user's answer>'
pwsh <script> dismiss-question -Number 3 -Answer '<why it stopped mattering>'
pwsh <script> approve -Gate intake -Note '<the user's own words>'
pwsh <script> advance
pwsh <script> return-to-build
pwsh <script> switch-flow -Flow Detailed
pwsh <script> add-increment -At 2 -Scope '<scope>' -Description '<result>'
pwsh <script> move-increment -Number 4 -To 2
pwsh <script> defer-increment -To 6
pwsh <script> remove-increment -Number 7
pwsh <script> finish
```

- `advance` rejects missing approvals or increments, wrong branches, uncommitted increments, and illegal transitions.
- `return-to-build` records a failed verification, invalidates the increment's verification approval, and resumes BUILD with the same increment identity.
- Before `add-increment`, `move-increment`, `defer-increment`, or `remove-increment`, read [references/increments.md](references/increments.md).
- Before proposing or running `switch-flow`, read [references/switch-flow.md](references/switch-flow.md).

## Gates

| Gate        | Where                                            | Meaning                                        |
| ----------- | ------------------------------------------------ | ---------------------------------------------- |
| `intake`    | `INTAKE` in both Detailed flows                  | the user says the request list is complete     |
| `implement` | Quick `DESIGN`, `SPLIT` in both Detailed flows   | the user has seen the plan and says build it   |
| `verify`    | `VERIFY`, once per increment                     | the user accepts that increment's verification |
| `integrate` | Detailed `SUMMARY`, Detailed Auto `FINAL_REVIEW` | the user says land the branch                  |

- The controller names the gate it expects. Detailed Auto refuses only `verify`, which it records itself. Quick `INTAKE` and Detailed `DESIGN` have no gate.
- Ask each user gate as an `an-dr-ai-send-message` confirmation, never a closing line like "reply implement": show the plan, increment, or summary first, then, in the same message, one approving option and one asking for a change.
- `-Note` is the chosen label plus any notes the user added; a widget choice counts as their own words; any other answer leaves the gate closed.
- A request recorded after `intake` approval drops it; the user closes the longer list again.
- The controller records approval evidence and never supplies it, in Detailed Auto too, where review, tests, doc checks, and clean commits still run between `implement` and final review.

## Questions

- `add-question` records, at any phase, what the agent cannot settle alone, instead of interrupting.
- `answer-question` and `dismiss-question` both require `-Answer`; a dismissal records why it stopped mattering.
- Ask accumulated questions as one `an-dr-ai-send-message` round; pass each echoed decision as `-Answer`.
- `approve -Gate implement` is refused while any question is open, listing the offenders.

## Share and finish

- Before committing progress state, moving work to another machine, or running `finish`, read [references/finish.md](references/finish.md).
