# Size and wording

## Description

- 1–2 sentences: what the skill does, then a `Use when ...` trigger.
- Trigger names the phrases and situations a user actually brings; generic ones are absent.
- No examples, rationale, diagrams, or "this skill helps you" phrasing.

## Body text

- Imperative and telegraphic in actions: "Archive X older than 7 days", not "You should consider archiving X".
- Declarative and telegraphic in concepts and conventions: "A commit subject is at most 72 characters".
- One rule per line; no intro paragraph, no closing recap.
- Rule-like content as `key: value`, short lists, or small tables.
- A reason appears only where it decides edge cases, as one clause.
- Absent: default behaviour ("be careful", "be accurate") and how standard tools work.
- Each rule stated once, in one place; elsewhere the owner is named.
- Notation is standard only: regex, glob, cron, `→`. No invented shorthand or emoji codes.

## Format by content

| Content                       | Format                                                        |
| ----------------------------- | ------------------------------------------------------------- |
| branching, 3+ decision points | Mermaid flowchart; conditions on edge labels, not in node IDs |
| linear steps                  | numbered list                                                 |
| rule set                      | table or `condition → action` lines                           |
| exceptions and reasons        | short prose after the diagram                                 |

- Mermaid replaces prose, a list, or a table wherever it carries the same or more understanding in the same or fewer tokens; otherwise the text stays.
- Mermaid is used, not PlantUML.

## Scripts

- Scripted: deterministic, exact, repeated steps — parsing, conversion, computation, file generation, date math, regex, API payloads.
- Prose: judgment calls, one-off steps, connector and MCP calls.
- Body: one line per script — when to run it and its arguments.
- Output is a compact summary, not a dump; failure is a one-line error, not a stack trace.
- Standard library where possible, no hard-coded paths, runs on every surface the skill is used on; `an-dr-convention-script` owns the rest.

## Progressive disclosure

- Body: main flow and decision points, well under 200 lines and within the token budget.
- Edge cases, long rule tables, examples, and templates live in `references/*.md`.
- The body says exactly when to read each reference: "For X, read references/x.md".

## Final pass

- A line stays only if the model would act wrongly without it.
- Token count is compared before and after; compression that adds tokens, such as symbols or emoji, is a regression.
