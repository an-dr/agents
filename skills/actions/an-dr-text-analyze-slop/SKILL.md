---
name: an-dr-text-analyze-slop
description: Analyze a text for AI slop — restating, padding, decoration, hollow polish, unverified specifics, and sections that carry less than their length suggests — and propose what to cut or say specifically. Use when the user hands over a document, README, instruction file, report, or message and wants to know what to cut or rewrite.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message an-dr-concept-ai-slop an-dr-convention-artifact-layout an-dr-convention-html-report
---

# Text slop analysis

Finds the sentences, sections, and structures in a text that cost the reader more than they give, and proposes the cut or the specific replacement. It judges how the text reads, not whether its facts are true: checking claims against sources is a separate action. A repository-wide analysis of code and documentation together is another.

## Inputs

- **The text**: a file, several files, or pasted text.
- **Its kind**: prose document, agent instructions, or a report or summary. Infer it from the text, and ask through `an-dr-ai-send-message` only when two kinds would give different findings.

## Method

1. Read the whole text before judging any part, so a repeat is seen as a repeat.
2. Apply the section of `an-dr-concept-ai-slop` that matches the kind: its signals for text, for agent instructions, or for reports, and its signals across artifacts.
3. For each candidate, run the cut, defence, and cost tests. Keep an item that has a reader, a constraint, or a reason; an unusual item with a reason is not slop.
4. Group repeated instances of one cause into one finding with representative locations.
5. For each finding, write the proposal: the cut, or the specific sentence that replaces the vague one. A replacement states a fact the text already supports; where none exists, the proposal is the cut or a question for the author.

## Findings

Give each finding a stable ID `TS-001`, `TS-002`, and so on, and these parts: the quoted location, the signal, the cost to the reader, and the proposal.

| Level | Finding |
| --- | --- |
| `high` | slop that misleads: a claim stronger than its support, a specific nobody checked, a conclusion no section backs |
| `notice` | slop that costs time: restating, padding, decoration, a section that says nothing new |
| `info` | a judgement call, shown with the reason it may be intentional |

Order findings by level, then by how much reader time they cost. An unflawed text gets one line saying so, never invented rows.

## Output

A table of 15 findings or fewer goes in the reply, by `an-dr-ai-send-message`'s finding levels. A longer analysis becomes an HTML page:

- write it as `text-slop.html` in the `text-slop` directory that `an-dr-convention-artifact-layout` gives you;
- build it through `an-dr-convention-html-report`, with each finding's level on its row;
- run `an-dr-convention-html-report`'s render scripts.

Report the page's path, and put only the opening lines and the `high` findings in the reply. End with the share of the text the proposals would remove, as a percentage or a word count — `31 of 37 words, 84%` — so the reader sees the size of the problem; the number of findings or cut clauses is not a share.

## Rules

- Analyze the text as written. Do not rewrite it unless the user asks; propose, and let them choose.
- Judge the text, not its author, and never infer machine authorship from style.
- Taste is not a finding: each one names the concrete cost to a reader.
- Do not invent findings to fill a quota.
