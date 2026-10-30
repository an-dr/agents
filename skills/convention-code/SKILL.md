---
name: convention-code
description: Writing defaults for source code — small changes, readable names and control flow, comments for newcomers, error handling, naming vocabulary, file layout, and reviewable commits of behaviour versus formatting. Use when writing, changing, or reviewing code; the host repository's own conventions override it.
metadata:
  dependencies: concept-clean-dependencies
---

# Convention: code

These are writing defaults. The host repository's instructions and the edited file's conventions override them. Review judges defects and reader cost, not preference compliance. Structure and dependencies follow `concept-clean-dependencies`.

## Code quality

- Make the smallest change that solves the stated problem. Avoid speculative options and abstractions.
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

## Reviewable changes

A human reviewer must be able to tell which lines change behaviour, and `git bisect` must be able to separate one cause from another.

- Keep formatter runs, re-wrapped prose, and other formatting-only edits out of behaviour changes. Do not reformat lines you are not otherwise changing unless the repository enforces a formatter.
- Do mechanical renames and migrations as their own pass, before any behaviour change that depends on them.
- After removing or moving a module, file, crate, or type, search for its name across code comments, scripts, documentation, and agent instructions, and update every reference to its new owner.
