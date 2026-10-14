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

## Architecture

Shape the code the way an experienced developer in this language and domain expects to find it, so a reviewer recognises the structure instead of reverse-engineering it.

- Keep dependencies pointing inward, as in Clean Architecture: domain rules and use cases depend on nothing outside them; I/O, frameworks, UI, transport, and persistence depend on them. Inner code reaches outer services through an interface it owns (a port), implemented by an adapter at the edge.
- Wire concrete implementations together in one composition root. Do not construct or look up outer services from inside domain or use-case code.
- Keep pure logic — parsing, validation, decisions, state transitions — free of I/O so it can be tested without the host, the network, or the UI.
- Model a lifecycle that spans several events as one explicit state owned by one unit, with named states and transitions, never as flags spread across methods of a larger class.
- Give each module one reason to change. When a class or file gains a second responsibility, extract it into a named unit instead of adding fields and branches to the existing one.
- Extend another component only through its public interface. When it has none, add the extension point to that component; never depend on its private markup, internal fields, or undocumented behaviour.
- Encode every format that crosses a process, component, or language boundary through the repository's shared codec or schema, with its fixtures. Do not hand-build bytes or ad-hoc JSON at a call site.
- Make an interface member required when every implementation provides it; optional members are for genuine absence, not convenience.
- Add structure for boundaries that exist now. This does not license speculative layers: a port with one adapter is justified by a real I/O or ownership boundary, not by a possible future one, and the smallest-change rule above still applies inside each unit.

## Names and structure

- Use the domain's own vocabulary and the ecosystem's standard terms: established pattern names (`Repository`, `Adapter`, `Controller`, `Factory`, `Builder`, `Coordinator`) only for code that is that pattern, and the language's naming, module, and directory conventions.
- Name each unit after its current responsibility. When a responsibility moves to a new owner, rename the types, messages, functions, and files that describe it in the same change, so no name still describes the old design.
- Never give two different concepts the same name within one codebase boundary, even in different modules.
- Lay out files where the ecosystem expects them — entry points, modules, tests, fixtures — and follow the repository's existing layout when it has one.

## Reviewable changes

A human reviewer must be able to tell which lines change behaviour, and `git bisect` must be able to separate one cause from another.

- Keep formatter runs, re-wrapped prose, and other formatting-only edits out of behaviour changes. Do not reformat lines you are not otherwise changing unless the repository enforces a formatter.
- Do mechanical renames and migrations as their own pass, before any behaviour change that depends on them.
- In Direct, each internal pass becomes its own commit, so a large request lands as a sequence of single-concern commits rather than one.
- After removing or moving a module, file, crate, or type, search for its name across code comments, scripts, documentation, and agent instructions, and update every reference to its new owner.
- Record a lasting decision through `docs-adr` when the change creates a public contract other programs depend on, or makes a deliberate exception to an existing ADR.

## Documentation and delivery

Human-facing documentation is prepared through `docs-writing` before changed behavior is coded. Doc comments belong beside code. If a documentation gap appears during gated BUILD, report it rather than silently filling it in code; in Direct, load `docs-writing` and update it before continuing. If existing documentation conflicts with code, surface the contradiction instead of silently choosing a side. For a gated flow, record the question with the controller; in Direct, ask only when the conflict blocks a sound decision.

Do not commit during gated BUILD. In Direct, commit only after verification and review, subject to the process repository's uncommitted review rule. Deliver code with the explanation required by `AGENTS.md`.
