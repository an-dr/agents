---
name: an-dr-concept-dark-cockpit
description: The attention model for any output that exists to find problems — normal results stay quiet, problems light up in proportion to consequence, red is reserved for critical, and no signal depends on colour alone. Use to decide which severity level an item takes and how loud it may be; implementors render the levels.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: concept
  an-dr.dependencies: PROHIBITED
---

# Concept: dark cockpit

A cockpit panel is dark when everything works; a light means something needs the pilot. Apply the same rule to every report whose purpose is finding problems: the reader's eye goes straight to what needs action, and a report that is all fine reads as calm rather than as a wall of green.

This concept owns the meaning of each level and the rules for using them. It owns no colour, class, glyph, script, or stylesheet: an implementor renders the levels for its medium. The calling skill owns which of its outcomes lands on which level.

An implementor renders the levels for each medium and owns its palette, classes, glyphs, weight, row order, and scripts: one for an HTML page, one for a Markdown table, terminal, or chat reply.

## The ladder

Map every item to exactly one level.

| Level | For | Loudness |
| --- | --- | --- |
| `critical` | Wrong result, data loss, security exposure, a false claim the conclusion rests on: blocks use or integration | the loudest signal the medium has, and the only one that may use red |
| `high` | A real problem that must be fixed, but does not by itself invalidate the result | clearly lit, never red |
| `notice` | Worth a look and a decision: minor issue, partial support, unconfirmed claim, warning | lit by weight and edge, no alarm hue |
| `info` | Neutral context the reader may need: scope, kind labels, what was not checked | secondary, unlit |
| `ok` | Passed, supported, verified, positive | dimmest, grouped, unlit |

## Rules

- **Normal is unlit.** Never celebrate success: no green, no check marks, no success banner. An all-clear report says so in one quiet line.
- **Red means critical, and only that.** Not for `high`, headings, accents, or counts. When more than a few items look critical, re-rank them: a report where everything is critical has no critical.
- **Colour is never alone.** Every lit level also carries its name and a glyph, so it reads in greyscale, in print, and for colour-blind readers.
- **Problems first.** Order items by level, `critical` down to `ok`, then by consequence within a level. Collapse `ok` items into one quiet group or count line unless the reader asked for every row.
- **Counts follow their level.** A zero count is `ok`; a non-zero count takes the level it counts.
- **No decorative hue.** Headings, borders, brand accents, and layout stay neutral, so a colour on the page always means a problem.
- **The brightest surface is a signal too.** Normal content sits on a muted surface; only lit items lift above it.
- **Quiet is still readable.** `ok` text is dimmed, not hidden.
- **Brand owns the unlit levels; alarms stay off-brand.** A brand may tint `ok`, `info`, and `notice`. `high` and `critical` never take a brand colour, because their job is to break the palette.

## Violations

A green success state, red used for emphasis, a level told apart by colour alone, `ok` rows listed above problems, and a page with no unlit majority all break the concept.
