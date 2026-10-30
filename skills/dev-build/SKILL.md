---
name: dev-build
description: Implement code during Direct work or gated BUILD. Use for coding changes after the selected workflow allows edits; follow repository patterns, documentation, and the requested scope.
metadata:
  dependencies: convention-adr convention-code docs-writing
---

# Build

Read the host `README.md`, `docs/index.md`, and project instructions before coding. In a gated increment, read the documentation written during DOCS as the specification. Find analogous code and match its structure, naming, formatting, error handling, and comment density.

Implement the requested result in Direct, or only the current increment in a gated flow. Follow the recorded design. Work discovered outside that scope becomes a separate request or future increment, not a silent expansion. Compile and run a relevant test subset after each touch-point so failures stay local. Write inline documentation with the implementation.

## Code conventions

Write code by `convention-code`: its quality, architecture, naming, and reviewable-change rules are the defaults here, and the host repository's own conventions override them.

## Commits and decisions

- In Direct, each internal pass becomes its own commit, so a large request lands as a sequence of single-concern commits rather than one.
- Record a lasting decision through `convention-adr` when the change creates a public contract other programs depend on, or makes a deliberate exception to an existing ADR.

## Documentation and delivery

Human-facing documentation is prepared through `docs-writing` before changed behavior is coded. Doc comments belong beside code. If a documentation gap appears during gated BUILD, report it rather than silently filling it in code; in Direct, load `docs-writing` and update it before continuing. If existing documentation conflicts with code, surface the contradiction instead of silently choosing a side. For a gated flow, record the question with the controller; in Direct, ask only when the conflict blocks a sound decision.

Do not commit during gated BUILD. In Direct, commit only after verification and review, subject to the process repository's uncommitted review rule. Deliver code with the explanation required by `AGENTS.md`.
