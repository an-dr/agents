# Report

## Opening, three lines

- Counts by verdict.
- The one sentence the conclusion most depends on, and its verdict.
- What the text speaks about that the evidence set does not cover.

## Claim ledger

| #   | Claim | Where | Kind | Verdict | Evidence | Note |
| --- | ----- | ----- | ---- | ------- | -------- | ---- |

- Claim: the shortest exact quote carrying the claim.
- Evidence: a precise locator (`file:line`, sheet and cell, quoted passage, computation); no locator → `not-found`, never `supported`.
- Note: what is wrong, or what would back the claim.

## Closing groups

- Accept: `supported` observed and derived claims.
- Fix: `contradicted` and `partial` claims, each with the corrected statement the evidence allows.
- Argue: inferences, assumptions, opinions, speculation, and `not-found` claims, each with its strongest counter-reading and the evidence that would settle it.

## Levels

One level per claim from its verdict; grounded claims stay dark so the eye lands on claims needing work.

| Level      | Claims                                                                  |
| ---------- | ----------------------------------------------------------------------- |
| `critical` | `contradicted`, when the conclusion or recommendation depends on it     |
| `high`     | any other `contradicted`; `not-found` when the conclusion depends on it |
| `notice`   | `partial`, any other `not-found`, assumptions the text leaves unstated  |
| `info`     | `unverifiable` opinion and speculation, shown with their kind           |
| `ok`       | `supported`                                                             |

- Sort the ledger by level, then consequence; `ok` rows in a collapsed group.

## Medium

- 15 rows or fewer → in the reply, with `an-dr-ai-use-user-interface`'s text levels.
- Longer → HTML page at a `claim-audit` path with extension `html`, in `an-dr-convention-html-report` format; each ledger row carries its level, verdict and kind as labels; build, verify, and publish through `an-dr-files-build-report`.
- HTML → reply holds the page's path, the opening lines, and the lit findings only.
