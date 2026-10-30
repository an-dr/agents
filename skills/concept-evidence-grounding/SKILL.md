---
name: concept-evidence-grounding
description: Keep every conclusion traceable to evidence — separate what was observed, calculated, inferred, assumed, and intended, and show uncertainty and coverage limits. Use when writing or judging any report, review, overview, README, test result, or diagnosis that states facts about something.
metadata:
  dependencies: PROHIBITED
---

# Concept: evidence grounding

A report is worth what its claims can be traced back to. This concept owns the principle behind every "do not fabricate" rule; each skill keeps its own procedure for gathering evidence.

## Kinds of statement

Know which kind each statement is, and let the reader know too wherever it could be mistaken for another.

| Kind | Basis |
| --- | --- |
| Observed | Read or run in this session: a file, a command's output, a test result |
| Derived | Calculated from observed values; the inputs are named |
| Inferred | A conclusion reasoned from observations; the reasoning is visible |
| Assumed | Taken as true without checking; says so |
| Intended | What a requirement, doc, or author claims should be true; not proof that it is |

## Rules

- **Trace.** A conclusion names or links its evidence. A claim with nothing behind it is cut, marked assumed, or turned into a question.
- **Never present inference as observation.** Plausible is not verified; an unrun check is reported as unrun.
- **Show coverage.** Say what was examined and what was not, so an empty finding list is not read as a clean bill.
- **Keep uncertainty at its size.** State a doubt once, where it applies, with what would settle it. Do not hedge everything, and do not drop a doubt that matters.
- **Intent is not behaviour.** When documentation and code disagree, report the disagreement; do not choose a side silently.
- **Missing input is a gap, not a blank to fill.** Ask for it or report the limit.

## Violations

An invented path, command, or figure; a "tests pass" that was not run; a summary stronger than the findings it summarises; a doc's claim repeated as fact about the code.
