---
name: dev-build
description: Implement code during Direct work or gated BUILD. Use for coding changes after the selected workflow allows edits; follow repository patterns, documentation, and the requested scope.
---

# Build

Read the host `README.md`, `docs/index.md`, and project instructions before coding. In a gated increment, read the documentation written during DOCS as the specification. Find analogous code and match its structure, naming, formatting, error handling, and comment density.

Implement the requested result in Direct, or only the current increment in a gated flow. Follow the recorded design. Work discovered outside that scope becomes a separate request or future increment, not a silent expansion. Compile and run a relevant test subset after each touch-point so failures stay local. Write inline documentation with the implementation.

## Code quality

- Make the smallest change that solves the stated problem. Avoid speculative options and abstractions.
- Use names and call sites a new reader can understand, with straight control flow and no hidden state to hold in mind.
- Give each unit one job. Split a block that needs a paragraph of explanation into named units.
- Comment intent beside the few lines it explains. Put whole-function explanations in doc comments; never restate obvious code.
- Keep one owner for each fact. Fail where the failure occurs, with enough context to act on it. Do not swallow errors.
- Delete dead or commented-out code. Preserve intentional stubs unless changing them is the task.
- Start function and method names with an action verb, except idiomatic constructors and builders. Document public interfaces and non-obvious decisions with Doxygen for C/C++, JSDoc for TS/JS, or docstrings for Python. Mark incomplete work with `TODO`.

The host repository's instructions and the edited file's conventions override these writing defaults. Review judges defects and reader cost, not preference compliance.

## Documentation and delivery

Human-facing documentation is prepared through `docs-writing` before changed behavior is coded. Doc comments belong beside code. If a documentation gap appears during gated BUILD, report it rather than silently filling it in code; in Direct, load `docs-writing` and update it before continuing. If existing documentation conflicts with code, surface the contradiction instead of silently choosing a side. For a gated flow, record the question with the controller; in Direct, ask only when the conflict blocks a sound decision.

Do not commit during gated BUILD. In Direct, commit only after verification and review, subject to the process repository's uncommitted review rule. Deliver code with the explanation required by `AGENTS.md`.
