---
name: retro
description: Process retrospective at the end of a Detailed flow (after MERGE) or on request — find where the process itself caused friction and propose AGENTS.md or skill amendments for the user's approval.
---

# Retro

Reviews the process, not the code. The instruction set is process
documentation that must evolve; the retro is its feedback loop.

## Process

1. **Collect evidence from this flow** — where phases stalled or looped,
   which rules were violated or needed clarification mid-flow, questions the
   user had to answer twice, increments that broke the size rule, VERIFY
   findings that a better DESIGN or an earlier review would have caught.
2. **Find the pattern** — a one-off mistake is not process feedback; a
   friction point that will recur is.
3. **Propose amendments** — at most 3 per retro, each a concrete edit to
   `AGENTS.md`, a role, or a skill: the exact wording change and the friction
   it removes. Present via the option-selection UI.
4. **Apply only what the user approves** — the instruction repo changes on
   direct user request only; the retro produces proposals, not edits. Commit
   and push every approved retrospective proposal after applying it.

## Rules

- Process only: code findings go to `code-review` or become new increments.
- Every proposal names the evidence from this flow that motivates it — no
  speculative rules.
- Prefer deleting or simplifying a rule over adding one; the instruction set
  stays lean.
