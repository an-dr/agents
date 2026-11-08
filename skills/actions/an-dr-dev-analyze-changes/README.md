# an-dr-dev-analyze-changes

Produces one HTML report of a finished change — what changed and why, new and upgraded components, dependency graphs, decisions, and verification — in diagrams and plain prose, so you can understand a change without reading the diff.

## When it runs

- At the integration gate of every Spec-driven or Supervised flow.
- After a delivery that adds a component, adds an ADR, or changes the architecture.
- After any other code delivery, only if you accept the one-line offer.

## How it works

The report is built only from evidence: the diff, the commits, the intake requests, touched ADRs, and the verification that actually ran. Anything not observed is listed as not verified.

| Section          | Shows                                                        |
| ---------------- | ------------------------------------------------------------ |
| Summary          | what changed and why, the constraints that shaped it         |
| Requests         | each requested item: done, partial, or not done              |
| Architecture     | the layers the change works within, as a diagram             |
| Dependency graph | affected components, new and changed ones marked             |
| New blocks       | per new component: responsibility, placement, a flow diagram |
| Upgraded blocks  | before, now, and why                                         |
| Decisions        | choices the plan left open, with reasons                     |
| Verification     | what was checked, what was not, known limits                 |
| Open items       | follow-up work and next commands                             |

Problems are marked with the dark-cockpit levels, so a clean change reads quietly.

## What you get

A `change-report` HTML page, linked from the pull request in gated flows, with the path or link in the reply.

## Related skills

- [an-dr-dev-follow-workflow](../an-dr-dev-follow-workflow/README.md) — calls it at SUMMARY.
- [an-dr-files-build-report](../an-dr-files-build-report/README.md) — builds and verifies the page.
