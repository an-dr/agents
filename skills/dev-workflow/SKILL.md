---
name: dev-workflow
description: Run, resume, and enforce the repository's Quick, Detailed, or Detailed Auto development workflow. Use whenever files will change, an existing .progress/workflow.json is present, workflow state must move to another machine, or increments must be inserted or reordered.
---

# Workflow controller

Use `scripts/workflow.ps1` as the authority for phase transitions and approval gates. Do not reconstruct workflow state from chat when `.progress/workflow.json` exists.

## Start or resume

From the host repository root, locate this embedded skill relative to the active `AGENTS.md`, then run:

```powershell
pwsh <skill-path>/scripts/workflow.ps1 status
```

If there is no active state, start one only after all four requirement fields are known:

```powershell
pwsh <skill-path>/scripts/workflow.ps1 start -Flow Detailed `
  -Goal '<problem>' -Constraints '<constraints>' -Done '<done>' `
  -OutOfScope '<exclusions>'
```

Supported flows:

- `Quick`: one build/verify/commit pass with user decisions and verification.
- `Detailed`: increments, a feature branch, per-increment user verification, integration summary, and explicit integration approval.
- `DetailedAuto`: the same engineering phases as Detailed, but the agent makes intermediate decisions and the user approves once at `FINAL_REVIEW`.

Use Detailed Auto only when the user explicitly requests autonomous or end-only involvement.

## Operate the workflow

```powershell
pwsh <script> add-question -Text '<what the user must decide>'
pwsh <script> answer-question -Number 2 -Answer '<the user's answer>'
pwsh <script> dismiss-question -Number 3 -Answer '<why it stopped mattering>'
pwsh <script> approve -Gate implement -Note '<the user's own words>'
pwsh <script> advance
pwsh <script> return-to-build
pwsh <script> add-increment -At 2 -Scope '<scope>' -Description '<result>'
pwsh <script> move-increment -Number 4 -To 2
pwsh <script> defer-increment -To 6
pwsh <script> remove-increment -Number 7
pwsh <script> finish
```

## Gates

Three gate names exist, and the controller names the one it expects for the current phase.

| Gate | Where | Meaning |
| --- | --- | --- |
| `implement` | Quick `DESIGN`, Detailed `SPLIT` | the user has seen the plan and says build it |
| `verify` | `VERIFY`, once per increment | the user accepts that increment's verification |
| `integrate` | Detailed `SUMMARY`, Detailed Auto `FINAL_REVIEW` | the user says land the branch |

Detailed Auto accepts only `integrate`; it records the rest itself. `START` and `DESIGN` in the Detailed flows have no gate at all — they advance freely, because nothing there touches a file.

## Questions

`add-question` records what the agent cannot settle alone, at any phase, instead of interrupting. `answer-question` and `dismiss-question` close one, and both demand an `-Answer`: a dismissal records why the question stopped mattering.

The controller refuses `approve -Gate implement` while any question is open and lists the offenders. This is the mechanism behind "explore first, build on command" — an unanswered question cannot be lost, because it holds the gate shut.

Run `status` before every response while state exists. Present the controller's Markdown status table to the user verbatim, as its emitted agent instruction requires. `advance` rejects missing approvals, missing increments, wrong branches, uncommitted increments, and illegal transitions. `return-to-build` records a failed verification, invalidates the increment's verification approval, and resumes BUILD without changing increment identity.

Only planned increments can be inserted or reordered with `move-increment`. Completed increments retain immutable IDs and fixed positions; renumbering never changes which increment is active.

`defer-increment` is the one way the *active* increment changes position. Use it when priorities move an untouched increment later — not to escape an increment already under way. It returns the active increment to `planned` at `-To`, starts the increment that now sits first among the planned ones, and stays in `BUILD`. It requires a clean working tree and refuses when no planned increment remains. The clean tree is the only evidence the controller has that nothing was built yet; work already committed under the increment is invisible to it, so never defer an increment whose commits are on the branch. Increment IDs survive a deferral, so its history and approvals stay attached to it.

`remove-increment` drops work the user has decided against. A completed increment is delivered history and cannot be removed. The active increment can be, under the same BUILD-and-clean-tree rule as `defer-increment`; the next planned increment then starts, or the flow moves to `SUMMARY` when none remains. Removing an increment is a scope change, so record why in the response — the plan no longer explains its own shape.

New work discovered in `SUMMARY` or `FINAL_REVIEW` can be added as an increment. The controller drops the `implement` and `integrate` approvals and returns to `SPLIT`, so the enlarged plan is authorized again before the new work passes through the branch cycle.

## Share and finish

`.progress/workflow.json` is intentionally committable. Include it in checkpoint and increment commits, then push normally when work must continue on another machine. Never add `.progress/` to an ignore file.

Every command that changes state also regenerates `.progress/PROGRESS.md`, a human-readable snapshot (flow, phase, goal, the iteration list with statuses, and the questions with their answers) with no IDs. Read it for a quick human-facing status check instead of parsing `workflow.json`. `finish` deletes it along with `workflow.json`.

Run `finish` at Quick/COMMIT before the final Quick commit, or at Detailed/INTEGRATE before integration. Commit the deletion, then run `dev-workflow-clean-branch` so `.progress/` is absent from every delivered feature-branch commit.

The controller records approval evidence; it never supplies user approval. In Detailed Auto, code review, tests, documentation checks, and clean commits still run automatically before the final user review.
