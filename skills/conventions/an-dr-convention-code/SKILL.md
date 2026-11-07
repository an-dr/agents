---
name: an-dr-convention-code
description: Writing defaults for source code — small changes, readable names and control flow, newcomer comments, error handling, naming, file layout, and reviewable behaviour-versus-formatting commits. Use when writing, changing, or reviewing code; the host repository's conventions override it.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: convention
  an-dr.dependencies: an-dr-concept-ai-slop an-dr-concept-clean-dependencies an-dr-convention-layout
---

# Convention: code

Defers: the cut test to `an-dr-concept-ai-slop`; structure and dependencies to `an-dr-concept-clean-dependencies`; file placement to `an-dr-convention-layout`. The host repository's instructions and the edited file's conventions override these defaults; review judges defects and reader cost, not preference compliance.

## Code quality

- A change is the smallest that solves the stated problem; no speculative options or abstractions.
- No comment, option, abstraction, or defensive branch whose removal loses nothing a reader needs.
- Names and call sites read clearly to a new reader; control flow is straight, with no hidden state to hold in mind.
- Each unit has one job; a block needing a paragraph of explanation is split into named units.
- Intent comments sit beside the few lines they explain; whole-function explanations are doc comments; obvious code is never restated.
- Comments describe what the code is and why, as it stands, for a newcomer; never by contrast with an earlier design ("no longer", "moved out of", "is not here any more"). History lives in commit messages, the changelog, and ADRs.
- Each fact has one owner.
- Failure is raised where it occurs, with context to act on; errors are never swallowed.
- Dead and commented-out code is deleted; intentional stubs stay unless changing them is the task.
- Function and method names start with an action verb, except idiomatic constructors and builders.
- Public interfaces and non-obvious decisions are documented: Doxygen for C/C++, JSDoc for TS/JS, docstrings for Python.
- Incomplete work is marked `TODO`.

## Names and structure

- Names use the domain's vocabulary and the ecosystem's standard terms and conventions for naming, modules, and directories.
- Pattern names (`Repository`, `Adapter`, `Controller`, `Factory`, `Builder`, `Coordinator`) only for code that is that pattern.
- A unit is named for its current responsibility; when a responsibility moves, its types, messages, functions, and files are renamed in the same change.
- Two different concepts never share a name within one codebase boundary, even in different modules.
- Files sit where `an-dr-convention-layout` places them; in a repository that departs from it, a new file sits beside existing files of its kind and the departure is reported, not copied silently.

## Architecture

Code takes the shape an experienced developer in the language and domain expects.

- Dependencies point inward: domain rules and use cases depend on nothing outside; I/O, frameworks, UI, transport, and persistence depend on them.
- Inner code reaches outer services through an interface it owns (a port), implemented by an adapter at the edge.
- Concrete implementations are wired in one composition root; domain and use-case code never construct or look up outer services.
- Pure logic (parsing, validation, decisions, state transitions) is free of I/O, testable without host, network, or UI.
- A lifecycle spanning several events is one explicit state owned by one unit, with named states and transitions, never flags spread across a larger class.
- Each module has one reason to change; a second responsibility is extracted into a named unit.
- Another component is extended only through its public interface; lacking one, the extension point is added to that component, never a dependency on private markup, internal fields, or undocumented behaviour.
- A format crossing a process, component, or language boundary goes through the repository's shared codec or schema, with fixtures; no hand-built bytes or ad-hoc JSON at a call site.
- An interface member every implementation provides is required; optional means genuine absence.
- Structure serves boundaries that exist now: a port with one adapter needs a real I/O or ownership boundary, not a possible future one; the smallest-change rule still applies inside each unit.

## Reviewable changes

A reviewer can tell which lines change behaviour, and `git bisect` can separate causes.

- Formatter runs, re-wrapped prose, and other formatting-only edits stay out of behaviour changes; untouched lines are not reformatted unless the repository enforces a formatter.
- A new project configures its ecosystem's standard formatter and linter (rustfmt and clippy, gofmt and go vet, Prettier and ESLint, ruff) with its first code and formats every file it writes; an existing repository without one gets the gap reported as follow-up, not reformatted.
- Mechanical renames and migrations are their own pass, before behaviour changes that depend on them.
- After a module, file, crate, or type is removed or moved, every reference in code comments, scripts, documentation, and agent instructions points to its new owner.
