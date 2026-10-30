---
name: concept-ai-slop
description: What AI slop is — output that looks finished and plausible but carries less information, or costs the reader more, than its length suggests — and how it shows up in code, text, agent instructions, and reports, with the tests and limits for recognising and avoiding it. Use when writing, reviewing, or auditing any generated artifact, and when deciding whether a line, section, or abstraction earns its place.
metadata:
  dependencies: PROHIBITED
---

# Concept: AI slop

Slop is output shaped to look complete rather than to serve a reader. It is fluent, tidy, and confident, and it costs more to read, maintain, or trust than the value it carries. A model drifts toward it by default, because filling a familiar shape is easier than deciding what the reader needs. This concept owns the definition, the tests, and how slop looks in each kind of artifact; the skills that write or judge artifacts apply it.

## The test

An item earns its place only if a reader acts, decides, or understands differently because it is there.

- **Cut test.** Remove the line, comment, section, option, or abstraction. If nothing the reader needs is lost, it was slop.
- **Defence test.** The author can say what it is for, who uses it, and what breaks without it. "It is thorough" and "it is conventional" are not answers.
- **Cost test.** Every kept item has a cost to the reader: time to read it, a place for it to go stale, or a path for it to be wrong. Value must exceed it.

## In code

- **Logic and consistency:** contradictory conditions, impossible states handled as if reachable, contracts that do not match between caller and callee, the same concept under two names.
- **Design and complexity:** abstractions, layers, or interfaces without a consumer; indirection that adds no boundary; options and configuration nobody sets; defensive branches for failures that cannot occur; workarounds whose original constraint no longer exists; two sources of truth for one fact.
- **Human understanding:** misleading names, surprising side effects, scattered ownership, unexplained exceptions, and interfaces whose normal use needs knowledge of hidden implementation details.
- **Comments:** a comment that restates the next line, narrates the change that produced the code, or explains nothing a name could not.
- **Scale:** a rewrite where an edit was enough, or verbose scaffolding that hides a simple operation.

## In text

- **Restating and padding:** a summary that repeats the text above it, an opening that announces the next paragraph, boilerplate framing, hedges on every claim, adjectives that add no fact.
- **Decoration:** headings, bullets, tables, bold, or emoji around a plain statement; structure that outweighs its content; three near-identical bullets where one thing was meant.
- **Hollow polish:** confident prose that never states the actual behaviour, a rationale that explains nothing, a conclusion stronger than its evidence, circular explanations.
- **Unverified specifics:** names, paths, commands, flags, figures, or quotations that were never checked against the source; unsupported claims; examples that do not run.
- **Stale or missing substance:** examples that no longer match the code, missing prerequisites, sections that promise behaviour the code does not provide.

## In agent instructions

- A rule that hedges, restates another rule, or explains what a script already enforces.
- A reminder where a failing check would do, and a list of examples where one resolves the ambiguity.
- Detail loaded at every start that only one task needs, and a rule placed where it never fires.
- Rules that differ between files, or describe a system as it used to work.

## In reports and summaries

- A long report whose conclusion no row supports, or whose counts do not match its table.
- Findings with no evidence, no cost, or no proposed change; positives listed to look balanced; coverage described as exhaustive when it was a sample.
- A summary that retells the diff instead of stating what changed, why, and what was left out.

## Across artifacts

- **Template residue:** placeholders presented as finished work, copied examples that do not fit the project, and conventions that differ between parts written together.
- **Drift:** one fact stated twice, a sentence that describes an earlier design, a count written next to the list it counts.

## Rules

- **Judge the artifact, not the author.** Never infer machine authorship from style. A finding names the concrete cost to a reader and the line it applies to.
- **Prefer less.** When an item fails the test, delete it. Rewriting slop in a better voice keeps the slop.
- **Say the specific thing.** Replace a vague claim with the fact, the number, the name, or the example, or remove the claim.
- **Size to the need.** The length of an artifact follows the information in it, not the shape of its kind.
- **Keep what has a consumer.** Before removing, check for a legitimate constraint or a user. An unusual item with a reason is not slop, and a taste preference is not a finding.
- **Group by cause.** Repeated instances of one cause are one problem, shown with representative places.
- **State doubt once.** Uncertainty belongs where it applies, with what would settle it, not spread as hedges.

## Violations

A summary that restates the section it ends; a comment above `i++`; a configuration option no caller sets; an interface with one implementation and no boundary; a README feature list that inventories instead of selecting; a report whose conclusion no row supports; a command in the docs that the repository does not provide; a heading over a single sentence; "robust, scalable, seamless" with no behaviour behind them.
