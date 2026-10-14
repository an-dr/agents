---
name: docs-html-report
description: Build a self-contained HTML report page for people, with Mermaid diagrams rendered offline by a pinned, embedded build. Use from any skill that writes an HTML page — change reports, code reviews, project overviews — or when the user asks for an HTML report with diagrams.
---

# HTML report

One file a reader can open from disk, in an editor preview, or as a published page, and see the same thing: text, tables, and rendered diagrams. The calling skill owns what the page says; this skill owns how it is built and how its diagrams render.

## The page

- One self-contained `.html` file: inline CSS and scripts, no fonts, styles, or scripts from the network.
- Define colours as CSS variables on `:root`, with dark values under `@media (prefers-color-scheme: dark)`, and give `body` an explicit background.
- Keep it usable at phone width: wide tables, code, and diagrams sit in their own `overflow-x: auto` container so the page never scrolls sideways.
- Stamp the page with what it was generated from — commit, branch, or range — and the date.

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
- Check every page after embedding by opening it, or by rendering it headless (`chrome --headless=new --virtual-time-budget=15000 --dump-dom <file-url>`) and searching the output for `aria-roledescription="error"`. A diagram that does not render is a defect in the page.

## Render

After writing the page, and again after every later edit of it, inline the pinned Mermaid build:

```powershell
pwsh <skill>/scripts/embed-mermaid.ps1 -Path <page>.html
```

The script is idempotent, works offline, follows the reader's light or dark theme, and reports how many diagrams the page holds. Never load Mermaid from a CDN. A host that renders Mermaid itself does not render the embedded diagrams twice.
