# Diagrams

- A diagram appears when structure or flow is the point: dependencies, layers, a request or handshake, a lifecycle, a decision. Never for what one sentence says.

| Shows                                                             | Mermaid type                           |
| ----------------------------------------------------------------- | -------------------------------------- |
| Layers, dependencies, C4 context, container, and component levels | `flowchart` with `subgraph` boundaries |
| Request flows, handshakes, message order                          | `sequenceDiagram`                      |
| Lifecycles and explicit states                                    | `stateDiagram-v2`                      |
| Branching behaviour                                               | `flowchart` with decision nodes        |

- Each diagram is a `<pre class="mermaid">` block of Mermaid source; `<`, `>`, `&` escaped as HTML entities; labels with punctuation quoted.
- Meaning is marked with shape, line style, and `classDef` stroke, not fixed fills, so both themes stay readable; styling is explained in a legend or caption.
- `flowchart`, not the experimental `C4*` types, which lay out unreliably.
- A chain of more than four nodes runs top to bottom (`flowchart TB`); a long left-to-right chain shrinks to unreadable text.
- Page CSS never styles `label`, `node`, `edgeLabel`, `cluster`, `actor`, `note`; it leaks into the SVG and clips text. Page classes have distinct names.
- No Mermaid keyword as a node id (`graph`, `flowchart`, `subgraph`, `end`, `class`, `classDef`, `style`, `click`, `default`, `direction`); such a diagram fails to parse.
