# an-dr-dev-review

Reviews a diff for defects, security issues, weakened checks, structure, convention violations, slop, and outdated patterns, records the findings in a JSON file, and renders them as an HTML report.

## When it runs

| Situation       | Diff reviewed                               |
| --------------- | ------------------------------------------- |
| A change        | the uncommitted changes, or the last commit |
| A whole branch  | the branch against its base                 |
| On your request | the range or codebase you name              |

## How it works

```mermaid
flowchart LR
  D[Select the diff] --> J[Judge: defects, security, structure, ergonomics, conventions, modernisation]
  J --> L[Layout check of added files]
  J --> S[Slop check of added lines]
  J --> W[check-weakening.py]
  L --> N[review-note.py per finding]
  S --> N
  W --> N
  N --> H[JSON record rendered to HTML]
```

- Every finding has a tight location and a concrete recommendation. Taste and writing preferences are not findings, and host conventions override general ones.
- Added files are placed by the layout convention; errors in paths the diff touches are findings, errors elsewhere are noted as existing debt.
- Slop in added lines — comments restating code, options nobody uses, unchecked paths — gets its own section.
- `check-weakening.py` lists added suppressions, skipped tests, stubs, deleted tests, and lost assertions; each one the change does not justify is a finding.
- For a non-trivial decision it offers a doubt pass: a fresh-context subagent sees only the claim and the diff and tries to disprove it. It runs only if you accept.

## What you get

A `code-review` JSON record (the authority) and an HTML report built from it, ranked by the dark-cockpit levels. Findings send the work back to implementation.

## Related skills

- [an-dr-dev-test](../an-dr-dev-test/README.md) — runs beside it in VERIFY.
- [an-dr-concept-dark-cockpit](../../concepts/an-dr-concept-dark-cockpit/README.md) — finding levels.
