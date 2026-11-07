---
name: an-dr-text-analyze-slop
description: Analyze a text for AI slop — restating, padding, decoration, hollow polish, unverified specifics, thin sections — and propose what to cut or say specifically. Use when the user hands over a document, README, instruction file, report, or message and wants to know what to cut or rewrite.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message an-dr-concept-ai-slop an-dr-files-build-report an-dr-convention-html-report
---

# Text slop analysis

Defers: signals and tests to `an-dr-concept-ai-slop`, HTML output to `an-dr-files-build-report`. Judges how the text reads; checking claims against sources and repository-wide code and documentation analysis are separate actions.

## Inputs

- Text: a file, several files, or pasted text.
- Kind: prose document, agent instructions, or report or summary. Infer it; ask through `an-dr-ai-send-message` only when two kinds would give different findings.

## Method

1. Read the whole text before judging any part, so a repeat is seen as a repeat.
2. Apply the `an-dr-concept-ai-slop` signals for the kind (text, agent instructions, or reports) and its signals across artifacts.
3. Run the cut, defence, and cost tests on each candidate; keep an item that has a reader, a constraint, or a reason.
4. Group repeated instances of one cause into one finding with representative locations.
5. Propose the cut, or the specific replacement sentence. A replacement states a fact the text already supports; otherwise propose the cut or a question for the author.

## Findings

Each finding: stable ID `TS-001`, `TS-002`, ...; quoted location; signal; cost to the reader; proposal.

| Level    | Finding                                                                                                         |
| -------- | --------------------------------------------------------------------------------------------------------------- |
| `high`   | slop that misleads: a claim stronger than its support, a specific nobody checked, a conclusion no section backs |
| `notice` | slop that costs time: restating, padding, decoration, a section that says nothing new                           |
| `info`   | a judgement call, shown with the reason it may be intentional                                                   |

- Order by level, then by reader time cost.
- An unflawed text gets one line saying so.

## Output

- 15 findings or fewer → table in the reply, by `an-dr-ai-send-message`'s finding levels.
- More → HTML page at a `text-slop` path, extension `html`, in the format of `an-dr-convention-html-report` with each finding's level on its row, built, verified, and published through `an-dr-files-build-report`. Reply with the page path, the opening lines, and the `high` findings.
- End with the share of the text the proposals remove, as percentage or word count (`31 of 37 words, 84%`); a count of findings or cut clauses is not a share.

## Rules

- Do not rewrite the text unless the user asks; propose and let them choose.
- Judge the text, not its author; never infer machine authorship from style.
- Taste is not a finding: each names a concrete cost to a reader.
- Do not invent findings to fill a quota.
