---
name: an-dr-concept-single-authority
description: Every fact, decision, and piece of mutable state has one authoritative owner; other copies derive from it or declare themselves snapshots, and conflicts are resolved, not picked. Use when state lives in several places, a rule repeats across files, a rendered output has a source, or sources disagree.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: concept
  an-dr.dependencies: PROHIBITED
---

# Concept: single authority

## Rules

- Each rule, decision, or piece of state has one named owner; everything else points to it by name or derives from it.
- A rendered report, summary, or cache is a snapshot: it carries what it was made from and is regenerated, not edited.
- A change made in a derived artifact is lost or becomes a second truth; changes belong in the source.
- Disagreeing sources are reported, the authoritative one identified, and the other fixed or reported; the convenient one is not simply picked.
- Conversation history does not outrank a state file, a controller result, or the code; the owner is the source.
- A restated rule is justified only by a detail specific to that point; otherwise its owner is named.

## Examples

| Fact                     | Authority                            | Derived                                                             |
| ------------------------ | ------------------------------------ | ------------------------------------------------------------------- |
| Workflow phase and gates | the workflow controller's state file | status tables, conversation recap                                   |
| Review findings          | the review JSON                      | the rendered HTML report                                            |
| Skill inventory          | the skill folders                    | the tables in `AGENTS.md` and `skills/README.md`, checked by script |
| Severity meaning         | the severity ladder                  | each renderer's styling                                             |

## Violations

- Two files defining the same rule with different wording.
- A report edited by hand after rendering.
- A status taken from what was said earlier instead of from the owner.
- A count written next to the list it counts.
