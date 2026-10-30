---
name: concept-single-authority
description: Every fact, decision, and piece of mutable state has one authoritative owner; other copies derive from it or declare themselves snapshots, and conflicts are resolved, not silently picked. Use when state is stored in more than one place, a rule is repeated across files, a rendered output has a source, or sources disagree.
metadata:
  dependencies: PROHIBITED
---

# Concept: single authority

A dependency graph can be acyclic and still keep two conflicting copies of the same truth. This concept owns the rule that prevents it.

## Rules

- **One owner per fact.** For each rule, decision, or piece of state, name where it lives. Everything else points to it by name or derives from it.
- **Derived copies say so.** A rendered report, a summary, or a cache is a snapshot of its source. It carries what it was made from, and is regenerated rather than edited.
- **Edit the source, never the copy.** A change made in a derived artifact is lost or, worse, becomes a second truth.
- **Conflicts are resolved, not chosen.** When two sources disagree, say so, find which one is authoritative, and fix or report the other. Do not pick the convenient one.
- **Memory is not a source.** Conversation history does not outrank a state file, a controller result, or the code. Read the owner again.
- **A repeat is justified only by what it adds.** Restating a rule is acceptable when it adds a detail specific to that point; otherwise name its owner instead.

## Examples

| Fact | Authority | Derived |
| --- | --- | --- |
| Workflow phase and gates | the workflow controller's state file | status tables, conversation recap |
| Review findings | the review JSON | the rendered HTML report |
| Skill inventory | the skill folders | the tables in `AGENTS.md` and `skills/README.md`, checked by script |
| Severity meaning | the severity ladder | each renderer's styling |

## Violations

Two files defining the same rule with different wording; a report edited by hand after rendering; a status taken from what was said earlier instead of from the owner; a count written next to the list it counts.
