---
name: an-dr-concept-ai-slop
description: What AI slop is — output that looks finished but carries less, or costs the reader more, than its length suggests — and how it shows in code, text, instructions, and reports. Use when writing, reviewing, or auditing any generated artifact, or judging whether an item earns its place.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: concept
  an-dr.dependencies: PROHIBITED
---

# Concept: AI slop

Slop: output shaped to look complete rather than to serve a reader — fluent, tidy, confident, and costing more to read, maintain, or trust than it carries. Models drift toward it by default, since filling a familiar shape is easier than deciding what the reader needs.

## The test

An item earns its place only if a reader acts, decides, or understands differently because it is there.

| Test    | Passes when                                                                                                           |
| ------- | --------------------------------------------------------------------------------------------------------------------- |
| Cut     | removing the line, comment, section, option, or abstraction loses something the reader needs                          |
| Defence | the author can say what it is for, who uses it, and what breaks without it; "thorough" or "conventional" is no answer |
| Cost    | its value exceeds its cost: reading time, a place to go stale, a path to be wrong                                     |

## In code

- Logic: contradictory conditions, impossible states handled as reachable, caller and callee contracts that disagree, one concept under two names.
- Design: abstractions, layers, or interfaces without a consumer; indirection with no boundary; options nobody sets; defensive branches for impossible failures; workarounds for constraints that no longer exist; two sources of truth.
- Understanding: misleading names, surprising side effects, scattered ownership, unexplained exceptions, interfaces needing hidden implementation knowledge.
- Comments: restating the next line, narrating the change, explaining what a name could.
- Scale: a rewrite where an edit sufficed; verbose scaffolding hiding a simple operation.

## In text

- Restating and padding: summaries repeating the text above, openings announcing the next paragraph, boilerplate framing, hedges on every claim, fact-free adjectives.
- Decoration: headings, bullets, tables, bold, or emoji around a plain statement; structure outweighing content; three near-identical bullets for one thing.
- Hollow polish: confident prose never stating actual behaviour, rationale explaining nothing, conclusions stronger than evidence, circular explanations.
- Unverified specifics: names, paths, commands, flags, figures, or quotations never checked against the source; unsupported claims; examples that do not run.
- Stale or missing substance: examples no longer matching the code, missing prerequisites, sections promising behaviour the code lacks.

## In agent instructions

- A rule that hedges, restates another rule, or explains what a script already enforces.
- A reminder where a failing check would do; a list of examples where one resolves the ambiguity.
- Detail loaded at every start that one task needs; a rule placed where it never fires.
- Rules differing between files, or describing a system as it used to work.

## In reports and summaries

- A long report whose conclusion no row supports, or whose counts do not match its table.
- Findings with no evidence, cost, or proposed change; positives listed for balance; a sample described as exhaustive.
- A summary retelling the diff instead of stating what changed, why, and what was left out.

## Across artifacts

- Template residue: placeholders presented as finished, copied examples that do not fit, conventions differing between parts written together.
- Drift: one fact stated twice, a sentence describing an earlier design, a count written next to the list it counts.

## Judgement

- The artifact is judged, not the author; machine authorship is never inferred from style. A finding names the concrete cost to a reader and the line.
- An item failing the test is deleted; rewriting slop in a better voice keeps the slop.
- A vague claim is replaced by the fact, number, name, or example, or removed.
- Length follows the information, not the shape of the artifact's kind.
- An unusual item with a legitimate constraint or consumer is not slop; a taste preference is not a finding.
- Repeated instances of one cause are one problem, shown with representative places.
- Doubt is stated once where it applies, with what would settle it, not spread as hedges.

## Violations

A summary restating the section it ends; a comment above `i++`; a configuration option no caller sets; an interface with one implementation and no boundary; a README feature list that inventories instead of selecting; a report whose conclusion no row supports; a documented command the repository lacks; a heading over one sentence; "robust, scalable, seamless" with no behaviour behind them.
