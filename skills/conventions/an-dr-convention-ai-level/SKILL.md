---
name: an-dr-convention-ai-level
description: The ai-level.dev standard for disclosing AI usage in a repository — the five levels from 0 to 4 and what each one claims. Use when naming, reading, or checking an AI-usage level.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: AI level

Owns: the [ai-level.dev](https://ai-level.dev) levels and their claims. Assessing a repository and placing the badge belong to a separate procedure.

## Levels

| Level | Tag                | Meaning                                                                         |
| ----- | ------------------ | ------------------------------------------------------------------------------- |
| 0     | `AI-FREE`          | No AI in any capacity: no code, docs, or assets.                                |
| 1     | `DOCS`             | AI only for documentation, error checking, or architectural consultation.       |
| 2     | `ASSETS / TOOLING` | AI for non-functional code, such as tests and configs, or creative assets only. |
| 3     | `ASSISTED`         | AI wrote individual functional modules under strict human review.               |
| 4     | `HEAVY AI`         | A significant portion of the codebase is AI-generated with limited review.      |

## Rules

- A repository takes the level of the most AI involvement in any of its parts.
- The level is the owner's disclosure, not a measurement; it is as trustworthy as its evidence.
