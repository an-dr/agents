---
name: an-dr-convention-code
description: Writing defaults for source code — small changes, readable names and control flow, comments for newcomers, error handling, naming vocabulary, file layout, and reviewable commits of behaviour versus formatting. Use when writing, changing, or reviewing code; the host repository's own conventions override it.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: convention
  an-dr.dependencies: an-dr-concept-ai-slop an-dr-concept-clean-dependencies
---

# Convention: code

These are writing defaults. The host repository's instructions and the edited file's conventions override them. Review judges defects and reader cost, not preference compliance. Structure and dependencies follow `an-dr-concept-clean-dependencies`.

## Code quality

- Make the smallest change that solves the stated problem. Avoid speculative options and abstractions.
- Write no comment, option, abstraction, or defensive branch that fails the cut test of `an-dr-concept-ai-slop`: if removing it loses nothing a reader needs, leave it out.
- Use names and call sites a new reader can understand, with straight control flow and no hidden state to hold in mind.
- Give each unit one job. Split a block that needs a paragraph of explanation into named units.
- Comment intent beside the few lines it explains. Put whole-function explanations in doc comments; never restate obvious code.
- Write every comment and doc comment for a newcomer who knows nothing of the project's history. Describe what the code is and why, as it stands. Never define it by contrast with an earlier design or the change that produced it ("no longer", "moved out of", "is not here any more"): that reader cannot know what it is contrasted with. History belongs in commit messages, the changelog, and ADRs.
- Keep one owner for each fact. Fail where the failure occurs, with enough context to act on it. Do not swallow errors.
- Delete dead or commented-out code. Preserve intentional stubs unless changing them is the task.
- Start function and method names with an action verb, except idiomatic constructors and builders. Document public interfaces and non-obvious decisions with Doxygen for C/C++, JSDoc for TS/JS, or docstrings for Python. Mark incomplete work with `TODO`.

## Names and structure

- Use the domain's own vocabulary and the ecosystem's standard terms: established pattern names (`Repository`, `Adapter`, `Controller`, `Factory`, `Builder`, `Coordinator`) only for code that is that pattern, and the language's naming, module, and directory conventions.
- Name each unit after its current responsibility. When a responsibility moves to a new owner, rename the types, messages, functions, and files that describe it in the same change, so no name still describes the old design.
- Never give two different concepts the same name within one codebase boundary, even in different modules.
- Lay out files where the ecosystem expects them — entry points, modules, tests, fixtures — and follow the repository's existing layout when it has one.

## Architecture

Structure components by `an-dr-concept-clean-dependencies`: no cycles, dependencies pointing toward stable abstractions, no layer skipping, and use of another component only through its public contract.

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

## Reviewable changes

A human reviewer must be able to tell which lines change behaviour, and `git bisect` must be able to separate one cause from another.

- Keep formatter runs, re-wrapped prose, and other formatting-only edits out of behaviour changes. Do not reformat lines you are not otherwise changing unless the repository enforces a formatter.
- Do mechanical renames and migrations as their own pass, before any behaviour change that depends on them.
- After removing or moving a module, file, crate, or type, search for its name across code comments, scripts, documentation, and agent instructions, and update every reference to its new owner.
