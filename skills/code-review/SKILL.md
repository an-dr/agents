---
name: code-review
description: Review a diff for defects, security issues, structural problems, and outdated patterns. Use during VERIFY on the increment diff and before MR on the full branch diff.
allowed-tools: Read, Grep, Glob, Bash
---

# Code review

## Scope

| Situation              | Diff to review                                                    |
| ---------------------- | ----------------------------------------------------------------- |
| VERIFY phase (default) | The current increment: uncommitted changes, or the last commit if the tree is clean |
| MR phase               | The full branch: `git diff main...HEAD`                           |
| On request             | A user-specified range or the full codebase                       |

## Focus

Ordered by severity; report in this order.

1. **Defects** — broken logic, unhandled errors, missed edge cases, resource
   leaks, race conditions.
2. **Security** — unvalidated input, injection, secrets in code, crypto misuse.
3. **Structure** — hidden coupling, wrong module boundaries, unnecessary
   complexity or over-engineering, reinvented standard library.
4. **Conventions** — violations of the *Code conventions* in `../../AGENTS.md`
   (verb-first names, comment brevity, present-tense descriptions, `TODO`
   markers) and of the host project's own style.
5. **Modernization** — deprecated APIs and legacy patterns with better modern
   equivalents in the language actually used.

## Output

Write the report to `docs/reviews/YYYY-MM-DD-<branch-or-ref>.md` in the host
repo (create `docs/reviews/` on first use) and summarize the critical
findings in chat. Every finding gets a stable ID so follow-up increments can
reference it.

```markdown
# Code review — <date>, <ref>

## Summary
<2–3 sentences: what changed, overall quality, count of critical findings>

## Findings

### Critical — must fix before merge
- **CR.1** `file:line` — <problem>. Fix: <concrete change>.

### High
- **CR.2** `file:line` — <problem>. Fix: <concrete change>.

### Improvements
- **CR.3** `file:line` — <observation>. Better: <alternative and why>.

## Positives
<specific good decisions worth keeping — no generic praise>

## Verdict
<approve | approve with comments | changes required — and why>
```

## Rules

- Be specific: `file:line` and a concrete fix for every finding — no generic
  advice, no fluff.
- State problems directly ("this breaks when…"), no hedging.
- Acknowledge honest tradeoffs; "good enough" can be the right call — say so.
- Review only: fixes are new BUILD work. Never commit.
