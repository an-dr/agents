---
name: workflow
description: Run, resume, and enforce the repository's Quick, Detailed, or Detailed Auto development workflow. Use whenever files will change, an existing .progress/workflow.json is present, workflow state must move to another machine, or increments must be inserted or reordered.
---

# Workflow controller

Use `scripts/workflow.ps1` as the authority for phase transitions and approval
gates. Do not reconstruct workflow state from chat when
`.progress/workflow.json` exists.

## Start or resume

From the host repository root, locate this embedded skill relative to the active
`AGENTS.md`, then run:

```powershell
pwsh <skill-path>/scripts/workflow.ps1 status
```

If there is no active state, start one only after all four requirement fields
are known:

```powershell
pwsh <skill-path>/scripts/workflow.ps1 start -Flow Detailed `
  -Goal '<problem>' -Constraints '<constraints>' -Done '<done>' `
  -OutOfScope '<exclusions>'
```

Supported flows:

- `Quick`: one build/verify/commit pass with user decisions and verification.
- `Detailed`: increments, a feature branch, per-increment user verification,
  merge review, and explicit merge approval.
- `DetailedAuto`: the same engineering phases as Detailed, but the agent makes
  intermediate decisions and the user approves once at `FINAL_REVIEW`.

Use Detailed Auto only when the user explicitly requests autonomous or
end-only involvement.

## Operate the workflow

```powershell
pwsh <script> approve -Gate requirements -Note '<user confirmation>'
pwsh <script> advance
pwsh <script> add-increment -At 2 -Scope '<scope>' -Description '<result>'
pwsh <script> move-increment -Number 4 -To 2
pwsh <script> finish
```

Run `status` before every response while state exists. Report its flow, phase,
and increment line verbatim. `advance` rejects missing approvals, missing
increments, wrong branches, uncommitted increments, and illegal transitions.

Only planned increments can be inserted or reordered. Completed and active
increments retain immutable IDs and fixed positions; renumbering never changes
which increment is active.

New work discovered in `MR`, `MERGE_READY`, or `FINAL_REVIEW` can be added as an
increment. The controller invalidates final approvals and returns to `SPLIT` so
the new work passes through the complete branch cycle before another review.

## Share and finish

`.progress/workflow.json` is intentionally committable. Include it in checkpoint
and increment commits, then push normally when work must continue on another
machine. Never add `.progress/` to an ignore file.

Run `finish` at Quick/COMMIT before the final Quick commit, or at Detailed/MERGE
before the final squash and merge. Commit the deletion so `.progress/` is absent
from the completed repository tree.

The controller records approval evidence; it never supplies user approval. In
Detailed Auto, code review, tests, documentation checks, and clean commits still
run automatically before the final user review.
