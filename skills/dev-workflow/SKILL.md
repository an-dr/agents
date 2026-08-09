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
pwsh <script> approve -Gate requirements -Note '<user confirmation>'
pwsh <script> advance
pwsh <script> return-to-build
pwsh <script> add-increment -At 2 -Scope '<scope>' -Description '<result>'
pwsh <script> move-increment -Number 4 -To 2
pwsh <script> defer-increment -To 6
pwsh <script> remove-increment -Number 7
pwsh <script> finish
```

Run `status` before every response while state exists. Present the controller's Markdown status table to the user verbatim, as its emitted agent instruction requires. `advance` rejects missing approvals, missing increments, wrong branches, uncommitted increments, and illegal transitions. `return-to-build` records a failed verification, invalidates the increment's verification approval, and resumes BUILD without changing increment identity.

Only planned increments can be inserted or reordered with `move-increment`. Completed increments retain immutable IDs and fixed positions; renumbering never changes which increment is active.

`defer-increment` is the one way the *active* increment changes position. Use it when priorities move an untouched increment later — not to escape an increment already under way. It returns the active increment to `planned` at `-To`, starts the increment that now sits first among the planned ones, and stays in `BUILD`. It requires a clean working tree and refuses when no planned increment remains. The clean tree is the only evidence the controller has that nothing was built yet; work already committed under the increment is invisible to it, so never defer an increment whose commits are on the branch. Increment IDs survive a deferral, so its history and approvals stay attached to it.

`remove-increment` drops work the user has decided against. A completed increment is delivered history and cannot be removed. The active increment can be, under the same BUILD-and-clean-tree rule as `defer-increment`; the next planned increment then starts, or the flow moves to `SUMMARY` when none remains. Removing an increment is a scope change, so record why in the response — the plan no longer explains its own shape.

New work discovered in `SUMMARY`, `MERGE_READY`, or `FINAL_REVIEW` can be added as an increment. The controller invalidates final approvals and returns to `SPLIT` so the new work passes through the complete branch cycle before another review.

## Share and finish

`.progress/workflow.json` is intentionally committable. Include it in checkpoint and increment commits, then push normally when work must continue on another machine. Never add `.progress/` to an ignore file.

Every command that changes state also regenerates `.progress/PROGRESS.md`, a human-readable snapshot (flow, phase, goal, and the iteration list with statuses) with no IDs. Read it for a quick human-facing status check instead of parsing `workflow.json`. `finish` deletes it along with `workflow.json`.

Run `finish` at Quick/COMMIT before the final Quick commit, or at Detailed/MERGE before integration. Commit the deletion, then run `dev-workflow-clean-branch` so `.progress/` is absent from every delivered feature-branch commit.

The controller records approval evidence; it never supplies user approval. In Detailed Auto, code review, tests, documentation checks, and clean commits still run automatically before the final user review.
