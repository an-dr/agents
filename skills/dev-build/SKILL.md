---
name: dev-build
description: Implement code during Direct work or gated BUILD. Use for coding changes after the selected workflow allows edits; follow repository patterns, documentation, and the requested scope.
metadata:
  dependencies: concept-clean-dependencies convention-adr convention-code docs-writing
---

# Build

Read the host `README.md`, `docs/index.md`, and project instructions before coding. In a gated increment, read the documentation written during DOCS as the specification. Find analogous code and match its structure, naming, formatting, error handling, and comment density.

Implement the requested result in Direct, or only the current increment in a gated flow. Follow the recorded design. Work discovered outside that scope becomes a separate request or future increment, not a silent expansion. Compile and run a relevant test subset after each touch-point so failures stay local. Write inline documentation with the implementation.

## Code conventions

Write code by `convention-code`: its quality, naming, and reviewable-change rules are the defaults here, and the host repository's own conventions override them.

## Architecture

Structure components by `concept-clean-dependencies`: no cycles, dependencies pointing toward stable abstractions, no layer skipping, and use of another component only through its public contract.

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

## Commits and decisions

- In Direct, each internal pass becomes its own commit, so a large request lands as a sequence of single-concern commits rather than one.
- Record a lasting decision through `convention-adr` when the change creates a public contract other programs depend on, or makes a deliberate exception to an existing ADR.

## Documentation and delivery

Human-facing documentation is prepared through `docs-writing` before changed behavior is coded. Doc comments belong beside code. If a documentation gap appears during gated BUILD, report it rather than silently filling it in code; in Direct, load `docs-writing` and update it before continuing. If existing documentation conflicts with code, surface the contradiction instead of silently choosing a side. For a gated flow, record the question with the controller; in Direct, ask only when the conflict blocks a sound decision.

Do not commit during gated BUILD. In Direct, commit only after verification and review, subject to the process repository's uncommitted review rule. Deliver code with the explanation required by `AGENTS.md`.
