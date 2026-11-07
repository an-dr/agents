---
name: an-dr-architecture-fix-dependencies
description: Untangle the dependencies of a skill, module, or package by writing an HTML analysis with a proposed fix per problem, then applying only the approved fixes. Use when a dependency graph has cycles, a component names more than it needs, or a component should become stable.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message an-dr-concept-clean-dependencies an-dr-files-build-report an-dr-convention-html-report
---

# Untangle dependencies

Defers: the principles to `an-dr-concept-clean-dependencies`, report format to `an-dr-convention-html-report`, building to `an-dr-files-build-report`.

Scope: whatever the user names, from one skill to the whole repository.

## Map

1. List the components in scope and every arrow between them: skills → registration check's cycle paths and declared dependencies; code → the language's dependency tooling.
2. Mark every cycle, every layer-skipping arrow, and every component whose contents do not change and get used together.
3. Record the starting numbers: arrows, cycles, components depending on many others.

## Judge each arrow

Take arrows one at a time, cycle arrows first, into one bucket each.

| Bucket    | Meaning                                                                         | Move                                                                |
| --------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Needless  | Serves nothing: a "see also", an example, a restated rule, a courtesy reference | Delete it                                                           |
| Misplaced | Needs a part another component owns but names the wrong owner or restates it    | Point to the owner; delete the restatement                          |
| Reversed  | A stable component names its consumer                                           | Delete the reverse arrow; the consumer points at it, results return |
| Shared    | Two components need the same part                                               | Extract it into a common component both depend on                   |
| Genuine   | The consumer cannot do its job without the other                                | Keep it, declared                                                   |

Choose the cheapest move that removes the arrow:

1. Delete a needless arrow.
2. Return, don't call: a worker hands a result, question, or blocker back instead of calling its coordinator.
3. Invert a dependency on a detail: the needing component defines the interface; the detail implements it.
4. Extract a shared part (concept, convention, foundation service), named for what it owns, never for its consumers; point both sides at it.
5. Merge or split components whose boundary cuts one reason to change, or bundles parts changing for different reasons.
6. Stabilise: mark the component stable the way its scope marks stable components; remove every dependency it carries.

## Analysis report

Change nothing yet.

1. Write one page at an `untangle` path with extension `html`; for levels and contents, read [references/report.md](references/report.md).
2. Escape repository text before inserting it into HTML.
3. Build, verify, and publish through `an-dr-files-build-report`; check that table rows and details agree.
4. Give the user the page's path. Graph already clean → say so and stop.

## Approval

- Ask through `an-dr-ai-send-message`: all, a subset by ID, or none.
- A change of ownership, a merge, or a split is its own question, even under "all".
- Apply nothing before the answer, and nothing it leaves out.

## Apply

- One approved move at a time; after each, rerun the checks and confirm arrow and cycle counts did not rise.
- A change with no behaviour effect gets its own pass.
- A finding that needs more than its proposal → report it; do not widen the change.

## Check

- Rerun registration and skill-text checks until they pass with no cycle among the approved findings.
- Code → rerun build and tests.

## Output

- Through `an-dr-ai-send-message`: starting and ending numbers, each move with its finding ID, new components and what they own, what was skipped or deferred and why.
- Offer to rewrite the report with the final graph.

## Rules

- The analysis report precedes any edit, even on "just fix it".
- Behaviour is unchanged: a move relocates ownership, never weakens, drops, or rewrites a rule.
- Move the rule, not just the mention; deleting an owner's name while keeping its rule creates a second owner.
- A new common component depends on nothing it serves.
- An arrow outside the named scope is reported, not changed.
- Extract only a part two components already need.
