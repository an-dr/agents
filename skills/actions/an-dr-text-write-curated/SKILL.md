---
name: an-dr-text-write-curated
description: Prepare a document in the document file itself through gated stages - target, sources, and destination, then a named file, a section skeleton, section-by-section drafting that honours the user's edits and notes in the file, and a final check of facts, slop, coherence, and options. Use when the user wants a document built carefully with their approval at each step rather than written in one pass.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "2.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-use-user-interface an-dr-text-verify-claims an-dr-text-analyze-slop an-dr-convention-artifact-layout
---

# Curated document writing

Defers: questions and gates to `an-dr-ai-use-user-interface`, fact checking to `an-dr-text-verify-claims`, slop analysis to `an-dr-text-analyze-slop`, fallback paths to `an-dr-convention-artifact-layout`.

## The file is the working tool

From stage 2 on, all work lives in the document file. Before every step, re-read the whole file: the user may have edited text, moved or renamed sections, or left notes anywhere. Treat each edit as approved content, never revert it, and act on each note; remove a note once it is handled and say how it was handled. Never rewrite a part the step does not touch.

Working notes go in one block at the top of the file, in the format's comment syntax (`<!-- ... -->` in Markdown and HTML): target, agreed sources, per-section status, accepted options. The block is removed at delivery.

## Gates

Every stage ends at a gate; never advance on silence. Before the file exists, ask in whatever form fits. Once it exists, each gate is exactly one question, pointing to the changed part of the file, with three answers: `Approved`, `Notes in the file` (re-read the file and act on them), and free input. Any open point goes into the file as a note for the user, not into further questions. A later stage may reopen an earlier one; say which and why.

## Stages

1. **Target, sources, destination.** Settle the reader, the purpose (what the reader knows or does afterwards), format, length budget, tone, and exclusions. Agree which sources the document may rest on: material the user supplies, repository files, web research, or none beyond the user's word; no research outside the agreed set. Settle the destination (see Destination). Ask for each missing fact; never invent one.
2. **File.** Propose the file name and path, derived from the purpose and the destination's naming habits. Once approved, create it with the title and the working-notes block only.
3. **Skeleton.** Add the section headings, each with a one-line placeholder saying what the section does for the reader and which agreed sources it draws on. When the shape is not obvious, describe 2-3 alternatives in chat before writing one. Gate: the user verifies the skeleton, in the file or in chat.
4. **Sections.** One section at a time, in order unless the user says otherwise:
   - re-read the file and apply the rules above;
   - list the claims and data the section needs; a claim without an agreed source is asked about, dropped, or marked as the user's word;
   - replace the placeholder with the section text;
   - gate: approve, revise, or restructure (back to stage 3). An approved section is frozen until the user reopens it.
5. **Final check.** Re-read the file, then on the whole document:
   - facts: `an-dr-text-verify-claims` against the agreed sources;
   - slop: `an-dr-text-analyze-slop`;
   - coherence: transitions, consistent terms, and fit to the stage 1 target and length budget;
   - options: concrete improvements (title, cuts, summary, tables or diagrams, alternative opening), each for the user to accept or reject.
   Apply only accepted changes, remove the working-notes block, then deliver.

## Destination

- Write where the user said, explicitly or by implication: a named path, an existing file being replaced, the repository's `docs/`, the location the target implies.
- Only when no destination is stated or implied, use an `an-dr-convention-artifact-layout` path of kind `curated-doc`.
- Replacing an existing file: work on it in place only after the user confirms; otherwise create a new file next to it.

## Delivery

Name the file, then list what the final check verified and what still rests on the user's word or on a source marked unchecked.
