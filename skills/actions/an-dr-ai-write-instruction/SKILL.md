---
name: an-dr-ai-write-instruction
description: Create or change instructions an agent loads — AGENTS.md, CLAUDE.md, skills, prompts, and their scripts — in the right carrier with observable rules. Use when writing or amending any agent instruction and verifying that tools can load it.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-review-instruction an-dr-concept-ai-slop an-dr-convention-markdown an-dr-dev-write-documentation
---

# Agent instruction writing

Defers: human-facing project prose to `an-dr-dev-write-documentation`, Markdown format to `an-dr-convention-markdown`, auditing to `an-dr-ai-review-instruction`.

## Place the rule

1. Base the change on an observed request, transcript, review finding, or failed run; state observed and desired behavior.
2. Read every instruction loaded before the rule fires.
3. Place it at its loading moment: always-on policy → `AGENTS.md`; one triggered action → a skill; deterministic check or transition → a script.
4. Move detail out of always-loaded context when a later carrier can own it.

## Write

- One imperative, observable rule at a time.
- Cut every sentence that fails the cut test of `an-dr-concept-ai-slop`; no hedges.
- Reason only when a rule otherwise seems arbitrary.
- Precedence stated beside rules that can conflict.
- One owner per fact; link to it elsewhere.
- Example only when it resolves ambiguity.
- Skill description: what it does and when to use it; tools match on it.
- Deterministic inputs and failure → a failing script, not a reminder.
- Describe the system as it works now.

## Verify

1. Format and check Markdown as `an-dr-dev-write-documentation` describes.
2. Audit with `an-dr-ai-review-instruction` and run its checks.
3. Reread the changed loading path as the receiving agent.

## Rules

- Never silently weaken an existing rule.
