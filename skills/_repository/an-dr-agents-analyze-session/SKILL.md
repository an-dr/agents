---
name: an-dr-agents-analyze-session
description: Find where the process itself caused friction in a finished flow and propose AGENTS.md or skill amendments for the user's approval. Use after a Detailed flow's integration or when the user asks for a retrospective.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-agents-repo-modify
---

# Retro

Defers: applying amendments to `an-dr-agents-repo-modify`.

## Run the retro

1. Collect evidence from this flow: phases that stalled or looped, rules violated or clarified mid-flow, questions the user answered twice, increments that broke the size rule, VERIFY findings a better DESIGN or earlier review would have caught.
2. Keep only friction that will recur; a one-off mistake is not process feedback.
3. Propose at most 3 amendments, each a concrete edit to `AGENTS.md`, a role, or a skill: exact wording change and the friction it removes. Present them through the option-selection UI.
4. Apply only approved proposals, each through `an-dr-agents-repo-modify`; the retro itself edits nothing.

## Rules

- Process only; code findings are out of scope.
- Every proposal names the evidence from this flow that motivates it.
- Prefer deleting or simplifying a rule over adding one.
