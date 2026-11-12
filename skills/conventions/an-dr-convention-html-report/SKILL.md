---
name: an-dr-convention-html-report
description: The format of an HTML report for people and the scripts that apply it — one self-contained file, problem levels, offline-rendered Mermaid, and a visual check. Use whenever a skill writes an HTML page for people, or the user asks for an HTML report with diagrams.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.3.0"
  an-dr.type: convention
  an-dr.dependencies: an-dr-concept-dark-cockpit an-dr-convention-artifact-layout an-dr-convention-html-repo-style
---

# Convention: HTML report

Owns: what only a report needs - stamp, problem levels, offline diagrams, verification; the calling skill owns what it says. Defers: how the page looks to `an-dr-convention-html-repo-style`, path, stamp, and latest copy to `an-dr-convention-artifact-layout`, the level ladder to `an-dr-concept-dark-cockpit`.

## Reference files

- [references/levels.md](references/levels.md): level classes, their look, and branded reports.
- [references/diagrams.md](references/diagrams.md): when to draw, Mermaid types, and source rules.

## The page

- Looks as `an-dr-convention-html-repo-style` says: one self-contained file, the brand tokens, the shared components, the theme switch, and the print layout.
- Stamp: the commit, branch, or range it was generated from, and the date.
- A page reporting findings, checks, verdicts, or risks carries problem levels and no other status colour. Calling skills hand over items with a level (`critical`, `high`, `notice`, `info`, `ok`) and never name classes, colours, or scripts.

## Scripts

- `scripts/embed-cockpit.ps1`: inlines the problem-level stylesheet; no-op without a `ck-` class; `-Html <markup>` returns embedded HTML without writing a file.
- `scripts/render-mermaid.ps1`: runs the pinned Mermaid build in local headless Chrome or Edge, replacing each `<pre class="mermaid">` with a figure holding a light and a dark SVG, a "Copy Mermaid" button, and the source. The page carries no renderer and shows the SVG matching the theme; a rerun re-renders from stored source.

## Visual verification

- Verified: screenshots of the actual page in light and dark themes, at desktop width and a true 390 CSS-pixel phone viewport, opened and inspected, with no layout defect left.
- Record: final HTML hash, screenshot paths, theme and viewport of each, which were opened, issues seen.
- Otherwise the page is unverified, whatever the renderer reported.
