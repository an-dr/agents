---
name: an-dr-dev-implement-code
description: Implement code following repository patterns, documentation, and the requested scope. Use for any coding change once edits are allowed.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-concept-evidence-grounding an-dr-convention-adr an-dr-convention-code an-dr-convention-layout an-dr-dev-write-documentation an-dr-git-modify-history
---

# Build

Defers: code style to `an-dr-convention-code`, sources to `an-dr-concept-evidence-grounding`, file placement to `an-dr-convention-layout`, ADR format to `an-dr-convention-adr`, documentation to `an-dr-dev-write-documentation`.

## Prepare

1. Read the host `README.md`, `docs/index.md`, and project instructions.
1. Read any documentation written for this change as its specification.
1. Find analogous code; match its structure, naming, formatting, error handling, and comment density.

## Implement

- Only the requested scope, following the recorded design; work outside it becomes a separate request.
- Compile and run a relevant test subset after each touch-point.
- Write inline documentation and doc comments with the code.
- A framework or library API the repository does not already use the same way → read its official documentation for the version the manifest or lockfile pins before writing the call, and name that page in the delivery explanation; memory of an API is not a source.
- Code follows `an-dr-convention-code`; host repository conventions override it.
- Place new files by `an-dr-convention-layout`, using its reference for the project type; a new project starts in that layout.

## Documentation and decisions

- Human-facing documentation is prepared through `an-dr-dev-write-documentation` before changed behaviour is coded.
- Documentation gap → update it through `an-dr-dev-write-documentation` before continuing.
- Documentation conflicts with code → surface it, never pick a side silently.
- Record an ADR, through `an-dr-dev-write-documentation`, when the change creates a public contract other programs depend on or deliberately departs from an existing ADR.

## Commit and deliver

- Commit only after verification and review, through `an-dr-git-modify-history`.
- Deliver with the explanation `AGENTS.md` requires.
