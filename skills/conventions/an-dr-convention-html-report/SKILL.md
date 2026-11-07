---
name: an-dr-convention-html-report
description: The format of an HTML report for people and the scripts that apply it — one self-contained file, the report brand, theme switch, print layout, problem levels, and offline-rendered Mermaid. Use whenever a skill writes an HTML page for people, or the user asks for an HTML report with diagrams.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.2.0"
  an-dr.type: convention
  an-dr.dependencies: an-dr-concept-dark-cockpit an-dr-convention-artifact-layout
---

# Convention: HTML report

Owns: how a page is built and how its diagrams render; the calling skill owns what it says. Defers: path, stamp, and latest copy to `an-dr-convention-artifact-layout`; the level ladder to `an-dr-concept-dark-cockpit`.

## Reference files

- [references/levels.md](references/levels.md): level classes, their look, and branded reports.
- [references/diagrams.md](references/diagrams.md): when to draw, Mermaid types, and source rules.

## The page

- One self-contained `.html` file, same from disk, editor preview, or published: inline CSS and scripts; no network fonts, styles, or scripts.
- Every colour and font comes from `assets/brand.css` (agramakov.me palette: dark-blue headings, grey text, fuchsia underlined links turning cyan on hover; light and dark values; body background, text, font; headings and links). Page styles use its `--brand-*` tokens and define no colour of their own.
- Paragraphs, list items, and table cells fill their container; prose is never capped by `max-width`, a `ch` measure, or a column narrower than its box. Long lines → narrow the whole layout column.
- Phone width: wide tables, code, and diagrams sit in their own `overflow-x: auto` container; the page never scrolls sideways.
- Theme switch (Auto / Light / Dark, remembered per browser) and print layout (white paper, light palette, collapsed `<details>` opened) come from `embed-brand.ps1`. A page has no own theme control, `data-theme` handling, or print palette; page styles add only layout rules under `@media print`.
- Stamp: the commit, branch, or range it was generated from, and the date.
- A page reporting findings, checks, verdicts, or risks carries problem levels and no other status colour. Calling skills hand over items with a level (`critical`, `high`, `notice`, `info`, `ok`) and never name classes, colours, or scripts.

## Scripts

- `scripts/embed-brand.ps1`: places the brand stylesheet before the page's styles and the theme switch at the body's start; a rerun replaces both.
- `scripts/embed-cockpit.ps1`: inlines the problem-level stylesheet; no-op without a `ck-` class; `-Html <markup>` returns embedded HTML without writing a file.
- `scripts/render-mermaid.ps1`: runs the pinned Mermaid build in local headless Chrome or Edge, replacing each `<pre class="mermaid">` with a figure holding a light and a dark SVG, a "Copy Mermaid" button, and the source. The page carries no renderer and shows the SVG matching the theme; a rerun re-renders from stored source.

## Visual verification

- Verified: screenshots of the actual page in light and dark themes, at desktop width and a true 390 CSS-pixel phone viewport, opened and inspected, with no layout defect left.
- Record: final HTML hash, screenshot paths, theme and viewport of each, which were opened, issues seen.
- Otherwise the page is unverified, whatever the renderer reported.
