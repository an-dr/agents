---
name: an-dr-concept-lab-notebook
description: A lab notebook records why work went the way it did — hypotheses before the run, results after, dead ends, decisions — append-only, with dated corrections instead of erasures and evidence linked to each entry. Use when keeping or reading a record of reasoning across sessions, or judging whether such a record can be trusted.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: concept
  an-dr.dependencies: PROHIBITED
---

# Concept: lab notebook

Adapted from Howard M. Kanare, *Writing the Laboratory Notebook* (American Chemical Society, 1985), as translated for coding agents in [Lab journal](https://lispmeister.github.io/deeprecursion/posts/2026-04-15-lab-journal.html).

## Rules

- **Permanence:** entries are appended, never edited or removed; a wrong entry gets a later correction that names it.
- **Immediacy:** an entry is written when the thing happens, not reconstructed at the end.
- **Prediction first:** a hypothesis states the expected outcome before the run; the result states what was measured and names the hypothesis it tests.
- **Completeness:** failures and abandoned approaches are recorded, so nobody retries them blind.
- **Self-containment:** each entry reads on its own and names commits, paths, and commands instead of copying content.
- **Witnessing:** an entry is trusted through independent evidence — a timestamp it did not write, a commit hash, a recorded user approval — never through the author's own assertion.
- **Lifetime:** a notebook lives as long as what it records; one tied to a temporary unit of work ends with that unit, and anything meant to outlast it moves into a permanent document.

## What it is not

| Record   | Holds                                      |
| -------- | ------------------------------------------ |
| History  | what happened, written by a tool           |
| Handoff  | where the work stands now, rewritten whole |
| Notebook | why: expected, measured, failed, decided   |

## Violations

- A result with no prior hypothesis, written to match what happened.
- An entry edited after the fact instead of corrected.
- A notebook that lists only successes.
- An entry that copies a diff or log instead of naming it.
- A claim of "tests pass" with no command, commit, or output named.
