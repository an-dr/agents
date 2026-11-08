---
name: an-dr-dev-analyze-changes
description: Produce one human-facing HTML report of a finished change — what and why, new and upgraded components, dependency graphs, decisions, verification — in diagrams and plain prose. Use at a Spec-driven or Supervised flow's integration gate, after a big change, or when the user accepts the offer after a smaller one.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.2.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message an-dr-concept-ai-slop an-dr-convention-adr an-dr-files-build-report an-dr-convention-html-report an-dr-dev-review an-dr-dev-write-documentation
---

# Change report

Defers: prose to `an-dr-dev-write-documentation`, page format and levels to `an-dr-convention-html-report`, build and publish to `an-dr-files-build-report`.

## Decide

- Spec-driven or Supervised flow, or a delivery that adds a component (crate, package, module, service), adds an ADR, or changes the architecture → write it.
- Any other code delivery → offer it in one line; write only when the user accepts.
- At the integration gate, before writing, read [references/integration-gate.md](references/integration-gate.md).

## Gather

Read the delivered diff, commits, intake requests or brief, touched ADRs and architecture docs, and the verification actually run. Every statement comes from that evidence; anything not observed goes under not verified.

## Write the sections

1. Summary: what changed and why in a few sentences, the rules or constraints that shaped the choices, and the commits, versions, or tags covered.
1. Requests: each requested item with status (done, partial, not done) and reason.
1. Architecture: the layers or boundaries the change works within, as a diagram.
1. Dependency graph: every affected component and its edges after the change; new, changed, and unchanged visually distinct, with a legend.
1. New blocks: per new component, its responsibility in one sentence, why it sits there, a flow or sequence diagram, its consumers, and its public interface only when the reader needs it.
1. Upgraded blocks: per changed component, before, now, and why.
1. Decisions: every choice the plan left open or the work departed from, with the reason.
1. Verification: what was checked and the result, what was not verified, known limitations.
1. Open items: follow-up work and next commands, such as a pending push.

Omit a section only when empty, and say so in the summary.

- Explain one change, not the whole repository; every section states something the reader needs, free of `an-dr-concept-ai-slop` signals.
- Mermaid: `flowchart` for layers and dependencies, `sequenceDiagram` for handshakes and request flows, decision flowcharts for branching.
- Levels for Requests and Verification: delivered or passed → `ok`; partial or unverified → `notice`; not done → `high`; failed check that ships → `critical`.
- Code only as interface signatures or the few lines an adopter writes; never implementation.

## Deliver

1. Write the page at a `change-report` path with extension `html`.
2. Build, verify, and publish it through `an-dr-files-build-report`, again after every later edit.
3. State whether verification is complete or blocked; generated HTML alone is not verified.
4. Publishing available → publish and give the link, saying when it is private to the user; otherwise name the file path.

## Rules

- The report edits nothing in the repository.
