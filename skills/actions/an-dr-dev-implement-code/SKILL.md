---
name: an-dr-dev-implement-code
description: Implement code during Vibe work or gated BUILD, following repository patterns, documentation, and the requested scope. Use for coding changes once the selected workflow allows edits.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-convention-adr an-dr-convention-code an-dr-convention-layout an-dr-dev-write-documentation
---

# Build

Defers: code style to `an-dr-convention-code`, file placement to `an-dr-convention-layout`, ADR format to `an-dr-convention-adr`, documentation to `an-dr-dev-write-documentation`.

## Prepare

1. Read the host `README.md`, `docs/index.md`, and project instructions.
1. In a gated increment, read the documentation written during DOCS as the specification.
1. Find analogous code; match its structure, naming, formatting, error handling, and comment density.

## Implement

- Vibe → the requested result; gated → only the current increment, following the recorded design.
- Work outside that scope becomes a separate request or future increment.
- Compile and run a relevant test subset after each touch-point.
- Write inline documentation and doc comments with the code.
- Code follows `an-dr-convention-code`; host repository conventions override it.
- Place new files by `an-dr-convention-layout`, using its reference for the project type; a new project starts in that layout.

## Documentation and decisions

- Human-facing documentation is prepared through `an-dr-dev-write-documentation` before changed behaviour is coded.
- Documentation gap in gated BUILD → report it, do not fill it in code; in Vibe → update it through `an-dr-dev-write-documentation` before continuing.
- Documentation conflicts with code → surface it, never pick a side silently; gated → record a controller question; Vibe → ask only when it blocks a sound decision.
- Record an ADR, through `an-dr-dev-write-documentation`, when the change creates a public contract other programs depend on or deliberately departs from an existing ADR.

## Commit and deliver

- Gated BUILD → no commits.
- Vibe → one commit per internal pass on its work branch, only after verification and review, subject to the process repository's uncommitted review rule.
- Deliver with the explanation `AGENTS.md` requires.
