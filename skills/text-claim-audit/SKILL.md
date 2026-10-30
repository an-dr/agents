---
name: text-claim-audit
description: Audit a text against the material it claims to be based on — split it into claims, label each as observed fact, derived figure, inference, assumption, opinion, or speculation, and check every one against the sources. Use when the user hands over a report, analysis, summary, or answer written by an AI or a person together with its data — other text, code, files, logs, spreadsheets — and wants to know what is backed, what is invented, and what is opinion.
metadata:
  dependencies: agents-ui concept-evidence-grounding convention-artifact-layout docs-html-report
---

# Text claim audit

Separates what a text *shows* from what it *asserts*, so the user can accept the grounded parts, fix the wrong ones, and argue the rest on its merits. The audit judges grounding, not quality: a well-written report can be unfounded, and a clumsy one can be exact.

## Inputs

- **The text under audit**: the report, summary, or answer.
- **The sources**: every file, dataset, document, codebase, or transcript the text is supposed to rest on.

Without sources there is nothing to ground against. Ask for them through `agents-ui`. When the user wants the audit anyway, still split and label the claims, and report every factual claim as `unverifiable`.

The sources are the only evidence. Your own background knowledge is not evidence. When it bears on a claim, put it in the note, labeled as outside knowledge, and leave the verdict unchanged. Do not audit whether the sources themselves are true, but report any place where a source contradicts itself.

## Method

1. **List the evidence set.** Name every source and what it covers: rows, period, files, version. The text's scope is measured against this list.
1. **Split into atomic claims.** One claim is one statement that can be checked on its own. Quote it and give its location. Split compound sentences. Treat the following as claims too:
   - connectives: *because*, *due to*, *drives*, *therefore*, *shows that*;
   - quantifiers: *most*, *all*, *rarely*, *significant*;
   - comparisons and trends;
   - every number, including rounded ones.
1. **Label each claim's kind.**

   | Kind | Means |
   | --- | --- |
   | `observed` | Stated directly by a source: a value, a quote, a line of code. |
   | `derived` | Computed from sources: a total, a ratio, a trend, a count. |
   | `inference` | Interpretation beyond the data: cause, intent, explanation, generalization. |
   | `assumption` | An unstated premise that another claim depends on. Write it out explicitly. |
   | `opinion` | A value judgment: *good*, *risky*, *should*, *the best*. |
   | `speculation` | A prediction or hypothetical: *will*, *likely*, *could*. |

1. **Check each claim against the evidence set.**

   | Verdict | Means |
   | --- | --- |
   | `supported` | The cited evidence states or entails it. |
   | `partial` | True only with a qualification the text drops: a narrower scope, a different period, a softer degree. |
   | `contradicted` | The evidence says otherwise. |
   | `not-found` | The evidence set has nothing on it. |
   | `unverifiable` | The claim cannot be settled by evidence at all, as with opinion and speculation. |

   - Recompute every `derived` figure yourself, and show the computation when it differs.
   - For an `inference`, check the premises first. Then check the step: name the alternative explanation the data equally allows, or the test that would rule it out.
   - Do not mark `opinion` or `speculation` true or false. State what it rests on and what evidence would move it.
1. **Look for what the text leaves out.** Find counter-evidence in the sources that the text omits. Check whether a sample is generalized to a whole population, whether an outlier is presented as a trend, and whether a selective window or a missing denominator distorts a figure. Record each as a claim of kind `assumption` or as an omission.
1. **Rank by consequence.** A claim the conclusion or recommendation depends on outranks a peripheral one. A `contradicted` or `not-found` claim at the top of the conclusion's reasoning is the headline finding.

## Report

Open with three lines:

- the counts by verdict;
- the one sentence the conclusion most depends on, and its verdict;
- what the evidence set does not cover that the text speaks about.

Then the claim ledger, one row per claim:

| # | Claim | Where | Kind | Verdict | Evidence | Note |
| --- | --- | --- | --- | --- | --- | --- |

- **Claim:** the shortest exact quote that carries the claim.
- **Evidence:** a precise locator, such as `file:line`, a sheet and cell, a quoted passage, or a computation. Without a locator the verdict is `not-found`, never `supported`.
- **Note:** what is wrong, or what would back the claim.

Close by sorting the claims into three groups for the user's next step:

- **Accept**: `supported` observed and derived claims.
- **Fix**: `contradicted` and `partial` claims, each with the corrected statement the evidence allows.
- **Argue**: inferences, assumptions, opinions, speculation, and `not-found` claims. Give each its strongest counter-reading and the evidence that would settle it.

### Presentation

Give every audit finding levels, which `agents-ui` renders in chat and `docs-html-report` in HTML. A grounded claim is normal state, so it stays dark, and the reader's eye lands on the claims that need work. Give each claim one level from its verdict:

| Level | Claims |
| --- | --- |
| `critical` | `contradicted`, when the conclusion or recommendation depends on it |
| `high` | any other `contradicted`, and `not-found` when the conclusion depends on it |
| `notice` | `partial`, any other `not-found`, and the assumptions the text leaves unstated |
| `info` | `unverifiable` opinion and speculation, shown with their kind so they stay easy to find |
| `ok` | `supported` |

Sort the ledger by level, then by consequence. Put the `ok` rows in a collapsed group.

A ledger of 15 rows or fewer goes in the reply, by `agents-ui`'s text levels. A longer audit becomes an HTML page:
- write it as `claim-audit.html` in the `claim-audit` directory that `convention-artifact-layout` gives you;
- build it through `docs-html-report`;
- give each claim's ledger row its level, and show its verdict and kind as labels;
- run `docs-html-report`'s render scripts.

Report the page's path, and put only the opening lines and the lit findings in the reply.

## Rules

The claim kinds follow `concept-evidence-grounding`.

- Audit the text as written. Do not rewrite it, soften it, or improve it unless the user asks.
- Neither the author's tone nor their confidence is evidence. Hedged wording does not excuse an unsupported claim, and confident wording does not support one.
- Keep `not-found` separate from `contradicted`: a missing fact is a gap, not a falsehood.
- Apply the same standard to text written by an AI and text written by a person, and do not guess which one wrote it.
