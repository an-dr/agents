---
name: dev-analysis-deslop
description: Analyse code and documentation for illogical design, contradictions, questionable complexity, misleading prose, and AI-like artifacts that make a human's work harder, on uncommitted changes, a commit or range, a branch diff, selected files or directories, or a whole repository, and deliver an HTML findings table with stable IDs, priorities, evidence, and proposed changes. Use when asked to deslop, audit coherence, or find questionable artifacts in a defined scope.
metadata:
  dependencies: agents-ui ai-prompt-review convention-artifact-layout dev-analysis-review docs-html-report
---

# Code and documentation coherence analysis

Inspect the requested code and documentation together from the perspective of the next human who must understand, use, or maintain them. Produce recommendations, not automatic fixes. This skill examines coherence within any selected scope, including diffs; `dev-analysis-review` provides the broader defect review, and `ai-prompt-review` examines agent instruction correctness.

## Establish scope

Resolve the scope from the user's request and the active task: uncommitted changes, a commit or range, a branch against its base, selected files or directories, or the whole repository. A request to deslop the current work targets that work's changes. Do not default to the whole repository when the scope is unspecified; ask through `agents-ui` only when the request and context do not identify it. For a branch diff, resolve and record the base and comparison method; ask if the intended base is ambiguous.

Read the repository instructions, README, documentation index, and the selected material. Exclude generated output, vendored dependencies, and build artifacts unless explicitly in scope. Record the scope, refs or paths, date, and whether uncommitted changes were inspected. For a large scope, identify the areas sampled and the areas not inspected; never describe a sample as an exhaustive audit.

For changes or branch diffs, focus findings on problems introduced or worsened by those changes. Read surrounding code and docs to understand their effects, but do not turn that context reading into a repository-wide audit or attribute pre-existing issues to the change.

Trace documented workflows to entry points, implementations, callers, and relevant tests. Read surrounding context before judging a suspicious fragment. Use existing checks or small read-only experiments when they can resolve uncertainty; distinguish checks actually run from suggested verification.

## What to examine

- Logic and consistency: contradictory conditions, impossible states, mismatched contracts, inconsistent terminology, and documentation that promises behavior the code does not provide.
- Design and complexity: abstractions without consumers, unnecessary indirection, duplicate sources of truth, speculative configurability, and workarounds whose original constraint no longer exists.
- Human understanding: misleading names, surprising side effects, scattered ownership, unexplained exceptions, and interfaces whose normal use requires knowledge of hidden implementation details.
- Documentation quality: stale examples, missing prerequisites, circular explanations, unsupported claims, repeated boilerplate, obvious comments, and polished prose that never explains the actual behavior.
- Incomplete or AI-like artifacts: placeholders presented as finished work, copied examples that do not fit the project, inconsistent conventions introduced together, and verbose scaffolding that obscures a simple operation.

Judge each item against the project's intent and conventions. Explain the concrete cost to correctness, use, understanding, or maintenance. Do not infer AI authorship from style, demand rewrites based only on taste, or invent findings to fill a quota. Check for a legitimate constraint or consumer before proposing removal. Group repeated instances of one cause into one finding with representative locations.

## Findings and priorities

Assign IDs `DS-001`, `DS-002`, and so on. Keep an ID attached to the same issue throughout revisions of this report, even if its priority or position changes; never reuse an ID for another issue. Retain resolved or withdrawn IDs in a quiet history section when revising an existing report.

Each finding states the observed evidence with file and line or documentation section, why it matters, and a concrete proposed change. Label its basis as **confirmed** or **question**. For a question, name the missing evidence and how to resolve it; phrase any change conditionally. Do not present an uncertain interpretation as a demonstrated defect.

Use these priorities, ordered by consequence rather than how easy a fix is:

- **P0 — critical:** demonstrated wrong results, data loss, security exposure, or a contradiction that blocks safe use. Map to the `critical` level.
- **P1 — high:** a confirmed problem with substantial user or maintenance cost that should be fixed soon. Map to `high`.
- **P2 — normal:** a local inconsistency, avoidable complexity, or documentation defect with a concrete cost. Map to `notice`.
- **P3 — low:** a small clarity improvement with an explained benefit. Map to `notice`.

Keep unconfirmed questions at P2 or P3 and state any potentially larger consequence separately. Priority measures action urgency; the evidence label measures certainty.

## HTML report

Use `convention-artifact-layout` to take a `deslop` directory in this run and write `deslop.html` there. Build one self-contained page through `docs-html-report`, and give findings and counts their priority level; that skill decides how levels look. Use `agents-ui` for tables and any questions to the user.

Include, in order:

1. Scope and provenance, including inspected areas, exclusions, and sampling limits.
1. A short conclusion with finding counts by priority; if none are substantiated, say so without manufacturing rows.
1. A findings table sorted by priority and consequence, with five columns: **ID**, **Priority / basis**, **Evidence and problem**, **Human impact**, **Proposed change**. Link each ID to a detail section when its evidence or proposal needs more space.
1. Details keyed by the same IDs, including relevant locations, the reasoning, constraints the fix must preserve, and a way to verify the proposed change. Distinguish observed behavior from inference.
1. Checks performed, limitations, and unresolved questions. Keep sound areas quiet rather than filling the page with positive findings.

Escape repository text before inserting it into HTML. Render and inspect the page as `docs-html-report` requires; check that every finding has a unique ID, priority, evidence, and an actionable proposal. Verify that table rows and details agree, and that the table is readable in both themes and at phone width. Add diagrams only when they explain a structural issue better than prose.

Deliver the HTML link or local path with a short summary of the most consequential findings. HTML is the report format; do not substitute a Markdown report. Leave source changes to a separately requested implementation task under the repository's applicable workflow.
