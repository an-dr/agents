---
name: an-dr-dev-analyze-changes
description: Produce one human-facing HTML report of a finished change — what was done and why, the responsibility of every new block, rendered Mermaid dependency graphs, a section per new and per upgraded component, decisions, and verification — explained with diagrams and plain prose rather than code. Use at the integration gate of a Detailed flow, at the end of a big change, or when the user accepts the offer at the end of a smaller one.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message an-dr-concept-ai-slop an-dr-convention-adr an-dr-convention-artifact-layout an-dr-convention-html-report an-dr-dev-review an-dr-dev-write-documentation
---

# Change report

One HTML page that lets a reader who did not watch the work understand what changed, why, and how the parts now fit. It explains a change, not a whole repository.

Use `an-dr-dev-write-documentation` for the prose, and keep the page free of the signals in `an-dr-concept-ai-slop`: every section states something the reader needs. The report describes work already delivered; it edits nothing in the repository.

## When

- **Write it** at the integration gate, and at the end of a big change: a Detailed or Detailed Auto flow, or any delivery that adds a component (crate, package, module, service), adds an ADR, or changes the architecture.
- **Offer it** in one line at the end of every other code delivery. Write it only when the user accepts.

## Gather first

Read the delivered diff, the commits, the intake requests or brief the work answered, the ADRs and architecture docs it touched, and the verification actually run. Every statement on the page comes from that evidence. Do not report a test, a measurement, or a behaviour that was not observed; list it under what was not verified instead.

## Sections, in order

1. **Summary** — what changed and why, in a few sentences, plus the rules or constraints that shaped the choices. Name the commits, versions, or tags the report covers.
1. **Requests** — each requested item with its status: done, partial, not done, with the reason.
1. **Architecture** — the layers or boundaries the change works within, as a diagram.
1. **Dependency graph** — every affected component and its edges after the change, with new, changed, and unchanged components visually distinct and a legend.
1. **New blocks** — one section per new component: its responsibility in one sentence, why it sits where it does, a flow or sequence diagram of how it works, its consumers, and its public interface only when the reader needs it.
1. **Upgraded blocks** — one section per existing component that changed: what it did before, what it does now, and why.
1. **Decisions** — every choice the plan left open or the work departed from, with the reason.
1. **Verification** — what was checked and the result, what was not verified, and known limitations.
1. **Open items** — follow-up work and the next commands, such as a push still waiting.

Omit a section only when it would be empty, and say so in the summary.

## Explain with diagrams, not code

- Draw structure and flow as Mermaid: `flowchart` for layers and dependencies, `sequenceDiagram` for handshakes and request flows, decision flowcharts for branching behaviour.
- Give the Requests statuses and the Verification results a level, and let `an-dr-convention-html-report` style them:
  - delivered requests and passed checks are `ok`;
  - a partial request or an unverified item is `notice`;
  - a request not done is `high`;
  - a failed check that ships is `critical`.
- Build the page and its diagrams through `an-dr-convention-html-report`, which owns the page rules, the diagram format, and the offline Mermaid renderer.
- Prose is plain and short. Code appears only as interface signatures or the few lines an adopter must write; never paste implementation.

## At the integration gate

In a Detailed flow, `SUMMARY` uses this skill for the full branch, after every increment is committed and before the final user approval gate. Before writing the page:

1. Run `an-dr-dev-review` with `summary` scope against the workflow's base branch.
2. Reconcile the branch against the intake request list in `.progress/workflow.json`. Every request the branch does not deliver is named in the handoff — as a deliberate exclusion, or as work that was missed. A request the user never withdrew and the branch never satisfied is a defect in the delivery, not a detail for the release notes.
3. Confirm the full test matrix, documentation consistency, exclusions, and any remaining risk. Documentation consistency includes the ADRs the branch added: none of them is integrated yet, so one correcting another from the same branch is a draft that should have been edited — collapse them before the handoff (`an-dr-convention-adr`).

Then write the report and return this exact handoff shape in the reply, with the report's link or path:

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

In `Requests delivered` and `How to verify`, follow `an-dr-ai-send-message`'s finding levels: list unmet requests and known failures first, with their level glyph, and delivered requests as plain lines.

An approving summary never grants integration permission. It is the material the user reads before giving the `integrate` approval — at `SUMMARY` in Detailed, at `FINAL_REVIEW` in Detailed Auto. That approval is then followed by the integration mode question, a separate decision the summary does not make.

## Write and deliver

Write the page as `<short-name>.html` in the `reports` directory `an-dr-convention-artifact-layout` gives you — this run's existing directory, so the report sits beside its code review — and render its diagrams as `an-dr-convention-html-report` describes, again after every later edit of the page. When the tool can publish pages, publish it and give the user the link; otherwise name the file path. Tell the user when the page is private to them.
