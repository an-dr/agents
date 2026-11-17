# SUMMARY

After the last build iteration's commit, `SUMMARY` prepares the result for approval with `an-dr-dev-analyze-changes` for the full branch.

## Before writing

1. Run `an-dr-dev-review` on the whole branch against its base.
2. Reconcile the branch against the intake request list in `tmp-agent-wip.json`; name every undelivered request in the handoff as a deliberate exclusion or as missed work. A request never withdrawn and never satisfied is a delivery defect.
3. Confirm the full test matrix, documentation consistency, exclusions, and remaining risk. Branch-added ADRs are not integrated, so one correcting another from the same branch is a draft: collapse them before the handoff (`an-dr-convention-adr`).

## Handoff

Write the report with `an-dr-dev-analyze-changes`, then return this exact shape with the report's link or path:

```text
## What changed
<1–3 bullet points>

## Requests delivered
<each request with the build iteration that satisfied it, and any that went unmet>

## Why
<motivation>

## What was left out
<explicit exclusions and why>

## How to verify
<numbered test steps>
```

- In `Requests delivered` and `How to verify`, use `an-dr-ai-use-user-interface` finding levels: unmet requests and known failures first with their level glyph, delivered requests as plain lines.
- The summary is what the user reads before approving the result at `SUMMARY`. Approval is not integration: the flow hands the branch over, and integrating it is a separate request.
