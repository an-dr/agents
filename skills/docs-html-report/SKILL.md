---
name: docs-html-report
description: Build a self-contained HTML report page for people, with Mermaid diagrams rendered offline to inline SVG by a pinned build, each with a button that copies its source. Use from any skill that writes an HTML page — change reports, code reviews, project overviews — or when the user asks for an HTML report with diagrams.
metadata:
  dependencies: concept-dark-cockpit convention-artifact-layout
---

# HTML report

One file a reader can open from disk, in an editor preview, or as a published page, and see the same thing: text, tables, and rendered diagrams. The calling skill owns what the page says; this skill owns how it is built and how its diagrams render.

## Where the page goes

A generated page is not repository content: take its directory from `convention-artifact-layout`, which owns where artifacts live, and report the path it prints to the reader.

## The page

- One self-contained `.html` file: inline CSS and scripts, no fonts, styles, or scripts from the network.
- Take every colour and font from the report brand, `assets/brand.css`. It holds the agramakov.me palette: dark-blue headings, grey text, and fuchsia underlined links that turn cyan on hover. It defines light and dark values, sets the body's background, text, and font, and styles headings and links. Page styles use its `--brand-*` tokens and define no colour of their own.
- Let paragraphs, list items, and table cells fill the width of their container. Never cap prose with `max-width`, a `ch` measure, or a fixed column narrower than its box: a paragraph that wraps early inside a wide card leaves a blank band beside it. Narrow the whole layout column instead when lines grow too long.
- Keep it usable at phone width: wide tables, code, and diagrams sit in their own `overflow-x: auto` container so the page never scrolls sideways.
- Every page gets a theme switch and a print layout, both supplied by `embed-brand.ps1`: the switch cycles Auto / Light / Dark and is remembered per browser; print uses white paper and the light palette, with collapsed `<details>` opened. Never write a page's own theme control, `data-theme` handling, or print palette; page styles may only add layout rules under `@media print`.
- Stamp the page with what it was generated from — commit, branch, or range — and the date.
- This skill decides whether a page needs problem levels. A page that reports findings, checks, verdicts, or risks gets them, as set out in the section below, and uses no other colour for status. Calling skills hand over items with a level (`critical`, `high`, `notice`, `info`, `ok`) and never name classes, colours, or scripts.

## Problem levels

This skill is the HTML implementor of `concept-dark-cockpit`, which owns the ladder and its rules. Mark each finding with one level class on its badge (`ck-badge`), its block (`ck-item`), or its table row. `embed-cockpit.ps1` then inlines the stylesheet, and does nothing when the page carries no `ck-` class, so the render step below is the same for every page.

| Level | Class | Look |
| --- | --- | --- |
| `critical` | `ck-critical` | red, filled badge, tinted background, `✖` |
| `high` | `ck-high` | amber, solid edge, `▲` |
| `notice` | `ck-notice` | full ink, no hue, dashed edge, `◆` |
| `info` | `ck-info` | secondary ink, no edge |
| `ok` | `ck-ok` | low-contrast grey, no hue, no edge |

- Collapse `ok` items into a closed `<details class="ck-quiet">`.
- Normal content sits on an off-white page, never pure white; only lit `notice` and `high` items lift to the white `--ck-lift` surface, and `critical` keeps its red tint. In dark themes the lift is the lightest panel.
- The script is idempotent and places `assets/dark-cockpit.css` before the page's own styles. It owns the palette for light and dark themes; page styles may use its `--ck-*` tokens but never define colours of their own for a level.

### Branded reports

When the reader asks for a branded report, the brand becomes the neutral layer:

- **The brand owns the unlit levels.** Brand colours replace the neutral chrome: headings, rules, and layout. A desaturated brand tint may carry `ok` and `info`, and the brand accent may carry `notice`.
- **Alarms stay off-brand.** `high` and `critical` never take a brand colour.
- **A red or orange brand stays in the chrome.** Its accent does not carry `notice`, and inside a finding it may colour only underlined links, never a fill, an edge, or a badge. `critical` stays red and is told apart by its filled badge, tint, and glyph.

To brand a page, define `--brand-ok`, `--brand-info`, and `--brand-notice`; the stylesheet reads them in place of its own greys, in either embedding order. `assets/brand.css` already defines them for every report. The alarm tokens have no brand input, and a page never overrides a `--ck-high*` or `--ck-critical*` token.

## Diagrams

Use a diagram when structure or flow is the point: dependencies and layers, a request or handshake, a lifecycle, a decision. Do not draw what one sentence says.

| Shows | Mermaid type |
| --- | --- |
| Layers, dependencies, C4 context, container, and component levels | `flowchart` with `subgraph` boundaries |
| Request flows, handshakes, message order | `sequenceDiagram` |
| Lifecycles and explicit states | `stateDiagram-v2` |
| Branching behaviour | `flowchart` with decision nodes |

- Write each diagram as a `<pre class="mermaid">` block holding the Mermaid source. Escape `<`, `>`, and `&` in that source as HTML entities; quote node labels that contain punctuation.
- Mark meaning with shape, line style, and `classDef` stroke settings rather than fixed fill colours, so diagrams stay readable in both themes. Explain any styling in a legend or caption.
- Prefer `flowchart` over Mermaid's experimental `C4*` diagram types, which lay out unreliably.
- Lay out a chain of more than four nodes top to bottom (`flowchart TB`); a long left-to-right chain shrinks to unreadable text at page width.
- Do not style generic class names that Mermaid also uses inside its SVG — `label`, `node`, `edgeLabel`, `cluster`, `actor`, `note` — on the page; give page classes distinct names, or the page CSS leaks into the diagrams and clips their text.
- Never use a Mermaid keyword as a node id — `graph`, `flowchart`, `subgraph`, `end`, `class`, `classDef`, `style`, `click`, `default`, `direction`. Such a diagram fails to parse; name the node after what it is instead.
- Open the page after rendering and look at every diagram in both themes. The render script already fails on a diagram Mermaid cannot parse; a diagram that parses but reads badly — clipped labels, a shrunken chain — is still a defect in the page.

## Render

After writing the page, and again after every later edit of it, inline the brand and render the diagrams:

```powershell
pwsh <skill>/scripts/embed-brand.ps1 -Path <page>.html
pwsh <skill>/scripts/embed-cockpit.ps1 -Path <page>.html
pwsh <skill>/scripts/render-mermaid.ps1 -Path <page>.html
```

The cockpit script is described under problem levels. The brand script places the stylesheet before the page's own styles, inserts the theme switch at the start of the body, and replaces both on a rerun.

`render-mermaid.ps1` runs the pinned Mermaid build in a local headless Chrome or Edge (`-Browser <exe>` when neither is found), and replaces each `<pre class="mermaid">` block with a figure holding a light and a dark SVG, a "Copy Mermaid" button, and the source. The page carries no renderer and shows the SVG matching the reader's theme. The script stops on any diagram that fails to parse and leaves the page unchanged. A rerun renders every figure again from its stored source, so edit a diagram by editing that source or by writing a new `<pre class="mermaid">` block. Never load Mermaid from a CDN.
