---
name: an-dr-text-write-curated
description: Prepare a document through gated stages - target, sources, structure, content plan, section-by-section drafting with approval, and a final check of facts, slop, coherence, and options. Use when the user wants a document built carefully with their approval at each step rather than written in one pass.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message an-dr-text-verify-claims an-dr-text-analyze-slop an-dr-convention-artifact-layout
---

# Curated document writing

Defers: questions and gates to `an-dr-ai-send-message`, fact checking to `an-dr-text-verify-claims`, slop analysis to `an-dr-text-analyze-slop`, fallback paths to `an-dr-convention-artifact-layout`.

## Gates

Every stage ends at a gate: show the stage result and wait for the user's approval in their own words. Revise on notes; never advance on silence. A later stage may reopen an earlier one; say which and why.

## Stages

1. **Target.** Settle the reader, the purpose (what the reader knows or does afterwards), format, destination, length budget, tone, and exclusions. Ask for each missing fact; never invent one.
2. **Sources.** Agree which sources the document may rest on: material the user supplies, repository files, web research, or none beyond the user's word. Record each agreed source and what it covers. No research outside the agreed set.
3. **Structure.** Propose an outline: each section's heading and one sentence on what it does for the reader. When the shape is not obvious, offer 2-3 alternatives with their trade-off.
4. **Content plan.** For each section, list the claims, data, and examples it needs, each bound to an agreed source or marked `from user` or `missing`. Resolve every `missing` item before drafting: obtain it, drop it, or reopen stage 2.
5. **Draft.** Write one section at a time and gate each: approve, revise, or restructure (back to stage 3). An approved section is frozen until the user reopens it.
6. **Final check.** On the assembled document:
   - facts: `an-dr-text-verify-claims` against the agreed sources;
   - slop: `an-dr-text-analyze-slop`;
   - coherence: transitions, consistent terms, and fit to the stage 1 target and length budget;
   - options: concrete improvements (title, cuts, summary, tables or diagrams, alternative opening), each for the user to accept or reject.
   Apply only accepted changes, then deliver.

## Destination

- Write where the user said, explicitly or by implication: a named path, an existing file being replaced, the repository's `docs/`, the location the target implies.
- Only when no destination is stated or implied, use an `an-dr-convention-artifact-layout` path of kind `curated-doc`.

## Delivery

Name the file, then list what the final check verified and what still rests on the user's word or on a source marked unchecked.

## State

Keep the target, agreed sources, outline, per-section status, and accepted options in a plan file in the system temp directory, so a later session resumes from it. Name its path to the user.
