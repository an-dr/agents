---
name: an-dr-concept-evidence-grounding
description: Every conclusion traces to evidence, with observed, calculated, inferred, assumed, and intended statements kept apart and uncertainty and coverage shown. Use when writing or judging any report, review, overview, README, test result, or diagnosis that states facts.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: concept
  an-dr.dependencies: PROHIBITED
---

# Concept: evidence grounding

Owns: the principle behind every "do not fabricate" rule. Each action keeps its own evidence-gathering procedure.

## Kinds of statement

Each statement has one kind; the reader sees it wherever it could be mistaken for another.

| Kind     | Basis                                                                          |
| -------- | ------------------------------------------------------------------------------ |
| Observed | Read or run in this session: a file, a command's output, a test result         |
| Derived  | Calculated from observed values; the inputs are named                          |
| Inferred | A conclusion reasoned from observations; the reasoning is visible              |
| Assumed  | Taken as true without checking; says so                                        |
| Intended | What a requirement, doc, or author claims should be true; not proof that it is |

## Principle

- A conclusion names or links its evidence; a claim with nothing behind it is cut, marked assumed, or turned into a question.
- Inference is never presented as observation; plausible is not verified; an unrun check is reported as unrun.
- Coverage is stated: what was examined and what was not, so an empty finding list is not read as clean.
- A doubt is stated once, where it applies, with what would settle it; no blanket hedging, no dropped doubt that matters.
- Documentation and code disagreeing is reported as a disagreement, never silently resolved.
- Missing input is a gap reported or asked for, never a blank filled.

## Violations

An invented path, command, or figure; a "tests pass" that was not run; a summary stronger than its findings; a doc's claim repeated as fact about the code.
