---
name: dev-untangle-dependencies
description: Untangle the dependencies of any component — a skill, module, or package — by first writing an HTML analysis of the problems with a proposed fix for each, then, once the user approves, removing unnecessary mentions and uses, breaking cycles, and moving shared parts into common components. Use when a dependency graph has cycles, a component names more than it needs, or a component should become stable.
metadata:
  dependencies: agents-modify agents-ui concept-clean-dependencies convention-agent-skill convention-artifact-layout docs-html-report
---

# Untangle dependencies

Apply `concept-clean-dependencies` to one scope in two stages: analyse and propose in an HTML report, then change only what the user approves. The scope is whatever the user names: one skill, a cluster, a package, or the whole repository. When the scope is a skill, its declarations and text follow `convention-agent-skill`, and a change to this repository's own skills lands through `agents-modify`.

## Map

1. List the components in scope and every arrow between them. For skills, run the registration check and read its cycle paths and declared dependencies; for code, use the language's own dependency tooling.
2. Record the starting numbers: arrows, cycles, and components that depend on many others. They are the proof at the end.

## Judge each arrow

Take arrows one at a time, starting with those on a cycle, and put each in one bucket.

| Bucket | Meaning | Move |
| --- | --- | --- |
| Needless | A mention or use that serves nothing: a "see also", an example, a restated rule, a courtesy reference | Delete it |
| Misplaced | The consumer needs a rule or part that another component owns, but names the wrong owner or restates it | Point to the owner, and delete the restatement |
| Reversed | A stable component names its consumer | Delete the reverse arrow; the consumer already points at it, and a result returns to the caller |
| Shared | Two components need the same part | Extract it into a common component both depend on |
| Genuine | The consumer cannot do its job without the other | Keep it, declared |

Choose the cheapest move that removes the arrow, in this order:

1. **Delete** a needless arrow.
2. **Return, don't call.** Replace a worker's call back into its coordinator with a result, question, or blocker handed back to the caller.
3. **Invert** a dependency on a detail: the component that needs it defines the interface, and the detail implements it.
4. **Extract** a shared part into a common component, such as a concept, a convention, or a foundation service, and point both sides at it. Name it for what it owns, never for its consumers.
5. **Merge or split** components whose boundary cuts through one reason to change, or that bundle parts changing for different reasons.
6. **Stabilise** a component that must not depend on others: mark it stable in the way its scope defines (for skills, `convention-agent-skill`), and remove every dependency it carries.

## Analysis report

Change nothing yet. Take an `untangle` directory for this run from `convention-artifact-layout` and write `untangle.html` there. Build one self-contained page through `docs-html-report`, and give each finding a level by consequence: a cycle through stable components is `critical`, a cycle among task components `high`, a needless or misplaced arrow `notice`, and a genuine arrow `ok`. That skill decides how levels look.

Include, in order:

1. Scope and provenance: what was mapped, how, and what was excluded.
2. The starting numbers and a one-paragraph conclusion. If the graph is already clean, say so and stop.
3. The current graph as a diagram, with the arrows on cycles marked.
4. A findings table sorted by level, with columns **ID**, **Level**, **Arrow or component**, **Problem**, **Bucket**, **Proposed move**. Every ID is stable and unique; link it to a detail section when the evidence or the move needs more room.
5. Details keyed by the same IDs: where the arrow comes from, why it is a problem, the exact edit proposed, and what it must preserve.
6. The proposed graph as a diagram and the projected numbers, so the reader sees the whole result before approving any part.
7. New components the proposal would create, each with what it owns; what was left alone and why; and open questions.

Escape repository text before inserting it into HTML, render and inspect the page as `docs-html-report` requires, and check that table rows and details agree. Give the user the page's path.

## Approval

Ask through `agents-ui` which findings to apply: all, a named subset by ID, or none. A change of ownership, a merge, or a split is its own question, even when "all" is chosen. Apply nothing before the user answers, and nothing the answer leaves out.

## Apply

Make each approved move one at a time, so a regression has one cause. After each move rerun the checks and confirm the arrow count and cycle count did not rise. Keep a change that has no behaviour effect in its own pass, and report any finding the edit turned out to need beyond its proposal instead of widening the change.

## Check

Rerun the registration and skill-text checks until they pass with no cycle among the approved findings. For code, rerun the build and tests.

## Output

Report with `agents-ui`: the starting and ending numbers, each move applied with the finding ID it answers, any new component and what it owns, and what was skipped or deferred and why. Offer to rewrite the report with the final graph.

## Rules

- **Report first.** The analysis report is produced before any edit, even when the user asks to "just fix it"; the proposal is what they approve.
- **Behaviour is unchanged.** A move relocates ownership; it never weakens, drops, or rewrites a rule to make an arrow disappear.
- **Move the rule, not just the mention.** Deleting the name of an owner while keeping its rule creates a second owner. Remove the restatement or move the rule to the one owner.
- **No new cycles.** A new common component depends on nothing it serves.
- **Stay in scope.** An arrow outside the named scope is reported, not changed.
- **Do not invent components.** Extract only a part that two components already need.
