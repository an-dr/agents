---
name: an-dr-convention-ai-level
description: The ai-level.dev standard for disclosing AI usage in a repository — the five levels from 0 to 4 and what each one claims. Use when naming, reading, or checking an AI-usage level.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: AI level

[ai-level.dev](https://ai-level.dev) is an open standard for telling readers how much AI was involved in building a project. This convention owns the levels and what each one claims. A separate procedure assesses a repository, assigns a level, and places the badge.

## Levels

| Level | Tag | Meaning |
| --- | --- | --- |
| 0 | `AI-FREE` | No AI was used in any capacity: no code, no docs, no assets. |
| 1 | `DOCS` | AI was used only for documentation, error checking, or architectural consultation. |
| 2 | `ASSETS / TOOLING` | AI was used for non-functional code, such as tests and configs, or for creative assets only. |
| 3 | `ASSISTED` | AI wrote individual functional modules under strict human review. |
| 4 | `HEAVY AI` | A significant portion of the codebase was AI-generated with limited review. |

## Rules

- **Highest involvement wins.** A repository takes the level of the most AI involvement in any of its parts.
- **A claim, not a measurement.** The level states what the owner discloses; it is as trustworthy as the evidence behind it.
