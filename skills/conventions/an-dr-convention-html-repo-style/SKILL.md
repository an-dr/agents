---
name: an-dr-convention-html-repo-style
description: The visual style of every HTML page in this repository - the brand palette and fonts, theme switch, print rules, shared components, and the two-column work surface. Use when a skill builds any HTML page, whether a report or an interactive page.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: convention
  an-dr.dependencies: none
---

# Convention: HTML repo style

Owns: how every page looks; a calling skill owns what it says, and a convention for a kind of page owns what only that kind needs.

## The page

- One self-contained `.html` file, the same from disk, an editor preview, or a local server: inline CSS and scripts, no network fonts, styles, or scripts.
- Every colour and font comes from `assets/brand.css` (the agramakov.me palette: dark-blue headings, grey text, fuchsia underlined links turning cyan on hover; light and dark values). Page styles use its `--brand-*` tokens and define no colour of their own.
- Shared building blocks come from `assets/components.css`, which uses only those tokens: `brand-page`, `brand-cols`, `brand-sticky`, `brand-section`, `brand-card`, `brand-note`, `brand-muted`, `brand-button`, `brand-input`, `brand-list`. A page adds layout rules only where no block fits.
- Paragraphs, list items, and table cells fill their container; prose is never capped by `max-width` or a `ch` measure. Long lines → narrow the whole layout column.
- Phone width: wide tables, code, and diagrams sit in their own `overflow-x: auto` container; the page never scrolls sideways.
- Theme switch (Auto / Light / Dark, remembered per browser) and print layout (white paper, light palette, collapsed `<details>` opened) come from `embed-brand.ps1`. A page has no own theme control, `data-theme` handling, or print palette.
- Status is a word, never a colour alone: a step or item says `doing`, `done`, or `problem` in text. Severity colours are never part of the brand.

## Work surface

A page the user works in, not only reads, has two columns on a wide screen: interaction on the left (forms, then earlier answers), progress on the right (`brand-sticky`, newest step first). Under 800 px they stack.

## Scripts

- `scripts/embed-brand.ps1`: places the brand and component styles before the page's own styles and the theme switch at the body's start; a rerun replaces both. A page generated at run time embeds a static template once, then fills it.
