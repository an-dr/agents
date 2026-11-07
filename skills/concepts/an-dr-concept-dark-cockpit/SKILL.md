---
name: an-dr-concept-dark-cockpit
description: The attention model for output that exists to find problems — normal results stay quiet, problems light up by consequence, red is reserved for critical, and no signal relies on colour alone. Use to decide which severity level an item takes and how loud it may be.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: concept
  an-dr.dependencies: PROHIBITED
---

# Concept: dark cockpit

Owns: meaning of each level and the rules for using them. Rendering (palette, classes, glyphs, weight, row order, scripts) belongs to an implementor per medium; which outcome lands on which level belongs to the calling skill.

## The ladder

Every item maps to exactly one level.

| Level      | For                                                                                                          | Loudness                                                             |
| ---------- | ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------- |
| `critical` | Wrong result, data loss, security exposure, a false claim the conclusion rests on: blocks use or integration | the loudest signal the medium has, and the only one that may use red |
| `high`     | A real problem that must be fixed, but does not by itself invalidate the result                              | clearly lit, never red                                               |
| `notice`   | Worth a look and a decision: minor issue, partial support, unconfirmed claim, warning                        | lit by weight and edge, no alarm hue                                 |
| `info`     | Neutral context the reader may need: scope, kind labels, what was not checked                                | secondary, unlit                                                     |
| `ok`       | Passed, supported, verified, positive                                                                        | dimmest, grouped, unlit                                              |

## Rules

- Normal is unlit: no green, no check marks, no success banner; an all-clear report is one quiet line.
- Red means `critical` only, never `high`, headings, accents, or counts; when more than a few items look critical they are re-ranked, since everything critical means nothing is.
- Every lit level also carries its name and a glyph, so it reads in greyscale, print, and for colour-blind readers.
- Items are ordered by level, `critical` to `ok`, then by consequence; `ok` items collapse into one quiet group or count line unless the reader asked for every row.
- A zero count is `ok`; a non-zero count takes the level it counts.
- Headings, borders, brand accents, and layout stay neutral, so any colour means a problem.
- Normal content sits on a muted surface; only lit items lift above it.
- `ok` text is dimmed, not hidden.
- A brand may tint `ok`, `info`, and `notice`; `high` and `critical` never take a brand colour, because their job is to break the palette.

## Violations

A green success state, red for emphasis, a level told apart by colour alone, `ok` rows above problems, a page with no unlit majority.
