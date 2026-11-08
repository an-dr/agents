# an-dr-dev-implement-code

Writes the code: follows the repository's existing patterns and documentation, and stays inside the requested scope.

## When it runs

During Vibe work, or in the BUILD phase of a gated flow once edits are allowed.

## How it works

```mermaid
flowchart LR
  P[Read README, docs, project rules] --> D[In a gated increment: DOCS output is the spec]
  D --> A[Find analogous code, match its style]
  A --> I[Implement, testing after each touch-point]
  I --> C{Flow}
  C -- gated BUILD --> N[No commit; COMMIT phase does it]
  C -- Vibe --> V[One commit per pass on vibe/slug, after review]
```

- **Scope.** Vibe delivers the requested result; a gated increment builds only that increment. Anything else becomes a separate request or a future increment.
- **Docs before behaviour.** Documentation for changed behaviour is written first. A gap found in gated BUILD is reported rather than filled in code; in Vibe it is fixed before continuing.
- **Conflicts are surfaced.** Where documentation and code disagree, the agent records a question rather than picking a side.
- **Style.** The code convention applies, the host repository's own conventions override it, and new files go where the layout convention puts them.

## What you get

Working code with doc comments, compiled and tested as it was written, and an explanation of what changed, why, and what was left out.

## Related skills

- [an-dr-convention-code](../../conventions/an-dr-convention-code/README.md) — writing defaults.
- [an-dr-dev-write-documentation](../an-dr-dev-write-documentation/README.md) — the docs it builds to.
- [an-dr-dev-test](../an-dr-dev-test/README.md) — verifies it.
