---
name: an-dr-ai-collect-input
description: Interview the user about any task after drafting from known information and identifying consequential gaps, with estimated coverage on every question and an option to stop. Use when the user asks for an interview or to collect input before completing a task.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-use-user-interface an-dr-concept-ai-slop an-dr-concept-evidence-grounding
---

# Collect input

Defers: questions and answers to `an-dr-ai-use-user-interface`, substance to `an-dr-concept-ai-slop`, and claims to `an-dr-concept-evidence-grounding`.

## Draft and identify gaps

1. Read the request, available conversation, and relevant accessible sources. Respect access restrictions and the task's existing permissions.
2. Form a private working draft or outline using what is known; do not write a deliverable or invent missing details. Separate evidence, inference, assumptions, and decisions.
3. Identify gaps whose answers could change the result, its usefulness, or its accuracy. Prioritize user-owned decisions and facts unavailable from accessible evidence; do not ask for facts already established.
4. Estimate coverage as the proportion of task-relevant information and decisions sufficiently known, weighted by importance. Treat it as a rough judgment, not a measured completeness or a promise of quality; revise the estimate when answers or new gaps change it.

## Interview

1. Use `an-dr-ai-use-user-interface` for each round. Begin every individual question with the current estimated task coverage, including in the question UI; use the same estimate within a round.
2. Ask the most consequential gaps first, in rounds of at most four. Use meaningful options where choices are clear and open questions where they are not; accept free text, corrections, and skipped answers.
3. At the start, tell the user they can say `stop` at any time and the task will continue with the information available. Offer `Stop interview` as an option on each selectable interview question without exceeding the messaging skill's option limit; open questions accept `stop` as text.
4. Incorporate each answer into the working draft and reassess gaps and coverage before the next round. Stop asking when the relevant gaps are resolved, the user stops, or no useful question remains.

## Continue the task

- On stop, immediately end the interview and proceed with the ordinary task workflow using the answers and available evidence. Do not treat skipped questions or stop as approval of defaults, actions, or workflow gates.
- Where information remains missing, use reasonable task-appropriate assumptions only when permitted, label consequential assumptions and uncertainty, and omit or report unsupported specifics. Do not fabricate facts.
- If a required approval or essential input is still missing, preserve the applicable gate or report the blocker; stopping the interview cannot waive it. If interaction is unavailable, proceed under the same rules without an interview.

## Output

Return the gathered facts, decisions, unresolved gaps, and consequential assumptions to the task, then complete it under its normal rules. Coverage estimates describe input coverage only, not task completion.
