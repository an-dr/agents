# At the integration gate

In a Spec-driven or Supervised flow, `SUMMARY` runs this skill for the full branch after every increment is committed and before the final approval gate.

## Before writing

1. Run `an-dr-dev-review` with `summary` scope against the workflow's base branch.
2. Reconcile the branch against the intake request list in `.progress/workflow.json`; name every undelivered request in the handoff as a deliberate exclusion or as missed work. A request never withdrawn and never satisfied is a delivery defect.
3. Confirm the full test matrix, documentation consistency, exclusions, and remaining risk. Branch-added ADRs are not integrated, so one correcting another from the same branch is a draft: collapse them before the handoff (`an-dr-convention-adr`).

## Handoff

Write the report, then return this exact shape with the report's link or path:

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

- In `Requests delivered` and `How to verify`, use `an-dr-ai-use-user-interface` finding levels: unmet requests and known failures first with their level glyph, delivered requests as plain lines.
- The summary never grants integration permission; it is what the user reads before the `integrate` approval (at `SUMMARY` in Supervised, `FINAL_REVIEW` in Spec-driven). It is linked from the pull or merge request; a local integration mode question, when needed, follows as a separate decision.
