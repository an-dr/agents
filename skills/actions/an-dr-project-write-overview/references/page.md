# Page

- One self-contained HTML file per `an-dr-convention-html-report`; opens from disk with no network.
- Start from `assets/overview-template.html` (structure, light and dark palette).
- C4 levels and main flow as Mermaid: `flowchart` with a `subgraph` boundary per C4 level; `sequenceDiagram` when the flow reads better as messages; `an-dr-files-build-report` renders them.
- Mark the system in focus, systems the project does not own, and inferred boxes with `classDef` stroke styles; legend in the caption.

## Levels

| Badge or severity | Level      |
| ----------------- | ---------- |
| `verified`        | `ok`       |
| `inferred`        | `notice`   |
| `claimed`         | `high`     |
| `blocker`         | `critical` |
| `major`           | `high`     |
| `minor`           | `notice`   |

No other badge colour.

## Sections, in order

1. What this is — three sentences, then the one thing to remember.
2. Facts — languages, size, containers, test ratio, CI, licence, last activity, the generating commit.
3. Start here — five files in reading order, one line each on why.
4. Context, container, component — the three diagrams, each under a short paragraph on what to notice.
5. The main flow — one primary use case traced end to end through the real call path.
6. Repository map — directory to purpose, marking generated, vendored, or dead.
7. Glossary — domain terms as the code spells them, especially where code and documentation use different words for one thing.
8. Intent versus reality — documentation says, code does, the file that settles it, verdict.
9. Problems and risks — the ranked findings.
10. Running it — build, run, and test commands copied from the repository, each verified to exist.
11. Open questions — what could not be established and what would settle it.
