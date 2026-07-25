---
name: summary
description: Prepare the full-branch integration summary after all Detailed increments are committed by reviewing the complete diff, confirming tests and documentation, and reporting changes, motivation, exclusions, and verification.
---

# Integration summary

Use during `SUMMARY`, after every increment is committed and before the final
user approval gate.

1. Run the `code-review` skill with `summary` scope against the workflow's base
   branch.
2. Confirm the full test matrix, documentation consistency, exclusions, and
   any remaining risk.
3. Return this exact handoff shape:

```text
## What changed
<1–3 bullet points>

## Why
<motivation>

## What was left out
<explicit exclusions and why>

## How to verify
<numbered test steps>
```

An approving summary never grants integration permission. Detailed requires its
merge-ready approval; Detailed Auto requires its final-review approval.
