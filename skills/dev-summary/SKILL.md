---
name: dev-summary
description: Prepare the full-branch integration summary after all Detailed increments are committed by reviewing the complete diff, confirming tests and documentation, and reporting changes, motivation, exclusions, and verification.
---

# Integration summary

Use during `SUMMARY`, after every increment is committed and before the final user approval gate.

1. Run the `dev-code-review` skill with `summary` scope against the workflow's base branch.
2. Reconcile the branch against the intake request list in `.progress/workflow.json`. Every request the branch does not deliver is named in the handoff — as a deliberate exclusion, or as work that was missed. A request the user never withdrew and the branch never satisfied is a defect in the delivery, not a detail for the release notes.
3. Confirm the full test matrix, documentation consistency, exclusions, and any remaining risk. Documentation consistency includes the ADRs the branch added: none of them is integrated yet, so one correcting another from the same branch is a draft that should have been edited — collapse them before the handoff (`docs-adr`).
4. Return this exact handoff shape:

```text
## What changed
<1–3 bullet points>

## Requests delivered
<each intake request with the increment that satisfied it, and any that went unmet>

## Why
<motivation>

## What was left out
<explicit exclusions and why>

## How to verify
<numbered test steps>
```

An approving summary never grants integration permission. It is the material the user reads before giving the `integrate` approval — at `SUMMARY` in Detailed, at `FINAL_REVIEW` in Detailed Auto. That approval is then followed by the `git-integrate` mode question, a separate decision the summary does not make.
