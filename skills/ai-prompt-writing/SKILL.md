---
name: ai-prompt-writing
description: Create or change instructions an agent loads, including AGENTS.md, CLAUDE.md, skills, prompts, and their scripts. Use to choose the right carrier, write observable rules, and verify that tools can load them.
---

# Agent instruction writing

Own agent-loaded instructions. Human-facing project prose belongs to `docs-writing`. Before editing, state the observed behavior and the desired behavior, then read every instruction loaded before the rule fires. Place the rule at its loading moment: `AGENTS.md` for always-on policy, a skill for one triggered action, and a script for deterministic checks and transitions. Push detail out of always-loaded context when a later carrier can own it.

Write one imperative, observable rule at a time. Remove hedges, give a reason only when a rule otherwise seems arbitrary, and state precedence beside rules that can conflict. Keep one owner for each fact and link to it elsewhere. An example earns its space only when it resolves ambiguity. Trigger-focused skill frontmatter must have a `name` matching its directory.

Change instructions against an observed request, transcript, review finding, or failed run. Do not silently weaken an existing rule. Prefer a failing script to a reminder when inputs and failure are deterministic. Instructions must describe the system as it works now.

Register a new skill in `AGENTS.md` and `skills/README.md`. Use `docs-md-writing` for Markdown format and `ai-prompt-review` for an instruction audit. Run their checkers, then reread the changed loading path as the receiving agent. If a skill or policy file is added, renamed, or moved, run `agents-health-check` to confirm tools can reach it.
