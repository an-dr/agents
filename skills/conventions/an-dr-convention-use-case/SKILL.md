---
name: an-dr-convention-use-case
description: What a use case is and how it is written — the documentation layer above architecture and design, stable UC-AREA-NN identifiers, the actor, goal, flow, and success fields, observable behaviour only, and one file per area with an index. Use when adding a capability, writing or reviewing a use case, or judging whether a change breaks what users rely on.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: use case

A use case states one goal someone reaches with the system, and what they observe when it worked. Together the use cases say what must keep working; architecture and design below them say how. A change that breaks a use case is a breaking change, whatever the code looks like, and a new capability arrives with the use case it serves.

## Location

`docs/use-cases/`, committed as ordinary repository content:

- `index.md` defines the layer for that repository: what a use case is, the fields, the actors it names, and a list of areas.
- One file per area, `<area>.md`, such as `docs/use-cases/cli.md`, holding that area's use cases under headings that group them by the user's activity.

Register the layer in the repository's documentation index, above architecture.

## Format

```markdown
### UC-<AREA>-<NN>: <goal in the actor's words>

- **Actor**: who acts.
- **Goal**: what they want, and why when it is not obvious.
- **Flow**: the steps, as the commands or actions they take.
- **Success**: what they observe when it worked.
```

- **Identifiers are stable.** `<AREA>` is a short uppercase code per area file and `<NN>` a two-digit number. An identifier stays when the use case is reworded or moved to another heading, and is never reused after the use case is removed. Order in the file follows the reader's activity, not the numbers.
- **Observable behaviour only.** Commands, files the user sees, and results — never a module, a function, or an internal file. An ordinary refactoring must not require a use case to change.
- **Name things the actor knows.** Define each actor once in `index.md`, by what they do, not by a project's internal role name. Say what is created, run, or captured, never a bare verb such as "start" or "run" without its object.
- **One goal each.** A use case that serves two actors' different goals is two use cases. Group by activity: creating something new, changing something that exists, and day-to-day work are different headings.

## Review

A use case passes when a newcomer can tell who acts, what they get, and how to check it without reading code. Reject one whose goal restates its command, whose success names no observable result, or that mixes two goals under one title.
