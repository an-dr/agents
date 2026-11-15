---
name: an-dr-convention-diagram
description: How much a diagram may show — one level of abstraction, a reading budget of about seven items, one loop, short trigger-only edge labels, and a shape that fits its length — and how an over-budget diagram splits into an overview and its parts. Use when drawing or reviewing any Mermaid diagram in Markdown or HTML; check-diagrams.ps1 in this skill measures it.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: convention
  an-dr.dependencies: none
---

# Convention: diagram

Owns: how much one diagram shows, how a bigger picture splits, and how its parts are told apart. How a diagram is embedded in a page belongs to whichever convention owns that page.

## Reading load

A diagram costs what the reader holds in mind at once, not its node count. The load comes from:

- items to read: every node, and every edge that carries a label;
- levels: a group with its own inside is a second diagram drawn inside the first;
- loops: each edge back to an earlier step asks the reader to remember where they were;
- shape: a long single row shrinks to small text and loses the eye;
- text: long labels compete with the nodes they connect.

## Budget

| Measure                       | Limit                                                                                               |
| ----------------------------- | --------------------------------------------------------------------------------------------------- |
| Items: nodes + labelled edges | 7; start and end markers do not count, nor a one-word outcome (`yes`, `no`) leaving a decision node |
| Levels                        | 1: no `subgraph` or composite state                                                                 |
| Loops                         | 1 edge back to an earlier step                                                                      |
| Edge label                    | 2 words, and only for a trigger or a decision outcome                                               |
| Left-to-right run             | 4 nodes; longer runs go top to bottom                                                               |

A diagram within every limit is left as it is. A generated reference graph that nobody reads at a glance, such as a full dependency graph behind a collapsed section, carries a `%% diagram-budget: exempt <reason>` line instead of being split.

## Splitting

- One diagram shows one level. A group with its own inside — a loop, a sub-process, a nested state — becomes one black-box node in the overview, and its inside becomes its own diagram.
- A black box looks different from a plain step, so the reader sees which boxes open into a diagram of their own: in a `flowchart` the subroutine shape `[[NAME]]`, in a `stateDiagram` a `blackbox` class with a double-weight dashed stroke (`classDef blackbox stroke-width:3px,stroke-dasharray:5 3` and `class NAME blackbox`). A one-line caption under the overview says what the marking means.
- The overview comes first; each part follows the sentence that introduces it, and names the overview node it opens.
- A part that is itself over budget splits again the same way.
- Explanations belong in the prose around a diagram, never on its arrows. The prose tells the story and the diagram shows its structure; each reads without the other.

## Types

| Shows                                                             | Mermaid type                           |
| ----------------------------------------------------------------- | -------------------------------------- |
| Layers, dependencies, C4 context, container, and component levels | `flowchart` with `subgraph` boundaries |
| Request flows, handshakes, message order                          | `sequenceDiagram`                      |
| Lifecycles and explicit states                                    | `stateDiagram-v2`                      |
| Branching behaviour                                               | `flowchart` with decision nodes        |

- A diagram appears when structure or flow is the point; never for what one sentence says.
- `flowchart`, not the experimental `C4*` types, which lay out unreliably.
- A layer diagram may keep `subgraph` boundaries when the boundaries are the point and the inside of each holds no more than the budget.
- Meaning is marked with shape, line style, and `classDef` stroke, not fixed fills, so light and dark themes stay readable; styling is explained in a legend or caption.
- No Mermaid keyword as a node id (`graph`, `flowchart`, `subgraph`, `end`, `class`, `classDef`, `style`, `click`, `default`, `direction`); such a diagram fails to parse.

## Check

`scripts/check-diagrams.ps1 -Path <files or folders>` reads every Mermaid block in Markdown (fenced `mermaid`) and HTML (`<pre class="mermaid">`), measures `flowchart`, `graph`, and `stateDiagram` blocks against the budget, lists other types as not measured, and exits non-zero when a block is over budget. It counts what it can parse; judging whether a split reads well is left to the reader. Regression tests are in `scripts/tests/`.
