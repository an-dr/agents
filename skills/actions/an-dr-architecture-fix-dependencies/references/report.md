# Analysis report

Format: `an-dr-convention-html-report`, which decides how levels look.

## Levels

| Finding                         | Level      |
| ------------------------------- | ---------- |
| Cycle through stable components | `critical` |
| Cycle among task components     | `high`     |
| Needless or misplaced arrow     | `notice`   |
| Genuine arrow                   | `ok`       |

## Contents, in order

1. Scope and provenance: what was mapped, how, what was excluded.
2. Starting numbers and a one-paragraph conclusion.
3. Current graph as a diagram, cycle arrows marked.
4. Findings table sorted by level: ID, Level, Arrow or component, Problem, Bucket, Proposed move. IDs are stable and unique; link an ID to its detail section when evidence or the move needs room.
5. Details keyed by ID: where the arrow comes from, why it is a problem, the exact edit proposed, what it must preserve.
6. Proposed graph as a diagram and projected numbers, so the reader sees the whole result before approving any part.
7. New components with what each owns; what was left alone and why; open questions.
