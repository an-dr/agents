---
name: an-dr-ai-write-instruction
description: Create or change instructions an agent loads, including AGENTS.md, CLAUDE.md, skills, prompts, and their scripts. Use to choose the right carrier, write observable rules, and verify that tools can load them.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-review-instruction an-dr-concept-ai-slop an-dr-convention-markdown
---

# Agent instruction writing

Own agent-loaded instructions. Human-facing project prose is out of scope. Before editing, state the observed behavior and the desired behavior, then read every instruction loaded before the rule fires. Place the rule at its loading moment: `AGENTS.md` for always-on policy, a skill for one triggered action, and a script for deterministic checks and transitions. Push detail out of always-loaded context when a later carrier can own it.

Write one imperative, observable rule at a time, and cut any sentence that fails the cut test of `an-dr-concept-ai-slop`. Remove hedges, give a reason only when a rule otherwise seems arbitrary, and state precedence beside rules that can conflict. Keep one owner for each fact and link to it elsewhere. An example earns its space only when it resolves ambiguity. Write a skill's description to say what the skill does and when to use it, because that is what a tool matches on to load it.

Change instructions against an observed request, transcript, review finding, or failed run. Do not silently weaken an existing rule. Prefer a failing script to a reminder when inputs and failure are deterministic. Instructions must describe the system as it works now.

Use `an-dr-convention-markdown` for Markdown format and `an-dr-ai-review-instruction` for an instruction audit. Run their checkers, then reread the changed loading path as the receiving agent.
