---
name: an-dr-text-verify-claims
description: Audit a text against its sources by splitting it into claims, labelling each claim's kind, and checking every one against the evidence. Use when the user hands over a report, analysis, summary, or answer with its data and wants to know what is backed, what is invented, and what is opinion.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message an-dr-files-build-report an-dr-convention-html-report
---

# Text claim audit

Defers: chat levels to `an-dr-ai-send-message`, HTML format to `an-dr-convention-html-report`, building to `an-dr-files-build-report`.

## Inputs

- The text under audit, and the sources it should rest on: files, datasets, documents, code, transcripts.
- No sources → ask for them through `an-dr-ai-send-message`; audit anyway on request, with every factual claim `unverifiable`.
- Sources are the only evidence. Background knowledge goes in the note, labelled outside knowledge, without changing the verdict.
- Do not audit whether sources are true; report where a source contradicts itself.
- The audit judges grounding, not writing quality.

## Method

1. List the evidence set: every source and its coverage (rows, period, files, version).
2. Split into atomic claims, each quoted with its location. Split compound sentences. Connectives (because, due to, drives, therefore, shows that), quantifiers (most, all, rarely, significant), comparisons, trends, and every number are claims.
3. Label each claim's kind; for the kind and verdict tables, read [references/labels.md](references/labels.md).
4. Check each claim against the evidence set:
   - recompute every `derived` figure; show the computation when it differs;
   - `inference` → check premises, then the step: name the alternative explanation the data equally allows, or the test that would rule it out;
   - `opinion`, `speculation` → never true or false; state what it rests on and what evidence would move it.
5. Find omissions: counter-evidence the text leaves out, a sample generalised to a population, an outlier shown as a trend, a selective window, a missing denominator. Record each as an `assumption` claim or an omission.
6. Rank by consequence: claims the conclusion or recommendation depends on first; a `contradicted` or `not-found` claim at the top of that reasoning is the headline.

## Output

For the report layout, levels, and the HTML threshold, read [references/report.md](references/report.md).

## Rules

- Audit the text as written; rewrite, soften, or improve it only on request.
- Tone and confidence are not evidence: hedging does not excuse an unsupported claim; confidence does not support one.
- `not-found` stays separate from `contradicted`: a gap, not a falsehood.
- Same standard for AI and human text; never guess the author.
