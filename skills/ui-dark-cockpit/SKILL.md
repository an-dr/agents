---
name: ui-dark-cockpit
description: Present findings so that normal results stay dark and only problems light up — quiet, low-contrast, hue-free rendering for what is fine, and a strict severity ladder with red reserved for critical problems. Use whenever an output exists to find problems — code reviews, audits, health checks, test and verification results, claim audits, overviews with risks — in an HTML page, a Markdown table, a terminal table, or a chat reply.
---

# Dark cockpit

A cockpit panel is dark when everything works; a light means something needs the pilot. Apply the same rule to every report whose purpose is finding problems: the reader's eye goes straight to what needs action, and a report that is all fine reads as calm rather than as a wall of green.

## The ladder

Map every item to exactly one level. The calling skill owns which of its outcomes lands on which level; this skill owns how each level looks.

| Level | For | HTML | Text |
| --- | --- | --- | --- |
| `critical` | Wrong result, data loss, security exposure, a false claim the conclusion rests on: blocks use or integration | red, filled badge, tinted background, `✖` | `✖ **CRITICAL**` |
| `high` | A real problem that must be fixed, but does not by itself invalidate the result | amber, solid edge, `▲` | `▲ **high**` |
| `notice` | Worth a look and a decision: minor issue, partial support, unconfirmed claim, warning | full ink, no hue, dashed edge, `◆` | `◆ notice` |
| `info` | Neutral context the reader may need: scope, kind labels, what was not checked | secondary ink, no edge | plain |
| `ok` | Passed, supported, verified, positive | low-contrast grey, no hue, no edge | plain, grouped |

## Rules

- **Normal is unlit.** Never colour success: no green, no check marks, no success banner. An all-clear report says so in one quiet line.
- **Red means critical, and only that.** Do not use red for `high`, for headings, for accents, or for counts. When more than a few items look red, re-rank them: a page where everything is critical has no critical.
- **Colour is never alone.** Every lit level also carries its name and glyph, so it reads in greyscale, in print, and for colour-blind readers.
- **Problems first.** Order items by level, `critical` down to `ok`, then by consequence within a level. Collapse `ok` items into a closed `<details class="ck-quiet">` in HTML, or into one count line in text, unless the reader asked for every row.
- **Counts follow their level.** A zero count is `ok`; a non-zero count takes the level it counts.
- **No decorative hue.** Headings, borders, brand accents, and layout stay neutral, so a colour on the page always means a problem.
- **The brightest surface is a signal too.** Normal content sits on an off-white page, never on pure white, and only lit `notice` and `high` items lift to the white `--ck-lift` surface. `critical` keeps its red tint. In dark themes the lift is the lightest panel.
- **Quiet is still readable.** `ok` text is dimmed, not hidden; it stays legible when the reader looks for it.

## HTML

Build the page through `docs-html-report`, mark each finding with one level class — `ck-critical`, `ck-high`, `ck-notice`, `ck-info`, `ck-ok` — on its badge (`ck-badge`), its block (`ck-item`), or its table row, then embed the stylesheet:

```powershell
pwsh <skill>/scripts/embed-cockpit.ps1 -Path <page>.html
```

The script is idempotent and places `assets/dark-cockpit.css` before the page's own styles. It owns the palette for light and dark themes; page styles may use its `--ck-*` tokens but never define colours of their own for a level.

## Branded reports

When the reader asks for a branded report, the brand becomes the neutral layer:
- **The brand owns the unlit levels.** Brand colours replace the neutral chrome: headings, rules, and layout. A desaturated brand tint may carry `ok` and `info`, and the brand accent may carry `notice`.
- **Alarms stay off-brand.** `high` and `critical` never take a brand colour. Their job is to break the palette.
- **A red or orange brand stays in the chrome.** Its accent does not carry `notice`, and inside a finding it may colour only underlined links, never a fill, an edge, or a badge. `critical` stays red and is told apart by its filled badge, tint, and glyph, never by moving it to another hue.

To brand a page, define `--brand-ok`, `--brand-info`, and `--brand-notice`. The stylesheet reads them in place of its own greys, in either embedding order. `docs-html-report`'s brand sheet already defines them for every report. The alarm tokens have no brand input, and a page never overrides a `--ck-high*` or `--ck-critical*` token.

## Markdown, terminal, and chat

Text has no colour, so order and weight carry the signal. Put lit rows first, bold only `critical` and `high`, prefix lit levels with their glyph, and end with the `ok` items as one line: `ok: 14 checks passed`.
