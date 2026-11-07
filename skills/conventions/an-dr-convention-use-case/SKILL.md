---
name: an-dr-convention-use-case
description: What a use case is and how it is written — the layer above architecture, stable UC-AREA-NN identifiers, actor, goal, flow, and success fields, observable behaviour only. Use when adding a capability, writing or reviewing a use case, or judging whether a change breaks what users rely on.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: use case

## Layer

- A use case is one goal someone reaches with the system and what they observe when it worked.
- Use cases say what must keep working; architecture and design below say how.
- A change that breaks a use case is a breaking change, whatever the code looks like.
- A new capability arrives with the use case it serves.

## Location

`docs/use-cases/`, committed as ordinary repository content:

- `index.md` defines the layer for that repository: what a use case is, the fields, the actors, and the list of areas.
- One file per area, `<area>.md` (e.g. `docs/use-cases/cli.md`), use cases grouped under headings by user activity.
- The layer is registered in the repository's documentation index, above architecture.

## Format

```markdown
### UC-<AREA>-<NN>: <goal in the actor's words>

- **Actor**: who acts.
- **Goal**: what they want, and why when it is not obvious.
- **Flow**: the steps, as the commands or actions they take.
- **Success**: what they observe when it worked.
```

- `<AREA>`: short uppercase code per area file; `<NN>`: two digits.
- An identifier stays when the use case is reworded or moved, and is never reused after removal.
- File order follows the reader's activity, not the numbers.
- Observable behaviour only: commands, files the user sees, results; never a module, function, or internal file, so an ordinary refactoring changes no use case.
- Each actor is defined once in `index.md` by what they do, not by an internal role name.
- Verbs carry their object: what is created, run, or captured, never a bare "start" or "run".
- One goal each; two actors' different goals are two use cases.
- Creating something new, changing something existing, and day-to-day work are different headings.

## Quality

- A newcomer can tell who acts, what they get, and how to check it without reading code.
- The goal does not restate the command.
- Success names an observable result.
