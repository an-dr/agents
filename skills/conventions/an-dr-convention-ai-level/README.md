# an-dr-convention-ai-level

The [ai-level.dev](https://ai-level.dev) standard for disclosing how much AI went into a repository: five levels, from 0 to 4, and what each one claims.

## When it runs

A convention is read, never run. Skills load it when naming, reading, or checking a repository's AI level.

## How it works

| Level | Tag                | Claim                                                            |
| ----- | ------------------ | ---------------------------------------------------------------- |
| 0     | `AI-FREE`          | No AI in code, docs, or assets                                   |
| 1     | `DOCS`             | AI only for documentation, error checking, or consultation       |
| 2     | `ASSETS / TOOLING` | AI for non-functional code, such as tests and configs, or assets |
| 3     | `ASSISTED`         | AI wrote functional modules under strict human review            |
| 4     | `HEAVY AI`         | Much of the code is AI-generated with limited review             |

A repository takes the level of its most AI-involved part. The level is the owner's disclosure, not a measurement, and is only as trustworthy as the evidence behind it.

## What you get

A shared meaning for the badge, so a reader knows what level 3 promises.

## Related skills

- [an-dr-dev-assign-ai-level](../../actions/an-dr-dev-assign-ai-level/README.md) — assesses a repository and adds the badge.
