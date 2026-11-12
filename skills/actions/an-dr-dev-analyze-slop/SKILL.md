---
name: an-dr-dev-analyze-slop
description: Analyse code and documentation in a defined scope for illogical design, contradictions, needless complexity, misleading prose, and AI-like artifacts, and deliver an HTML findings report. Use when asked to deslop, audit coherence, or find questionable artifacts in changes, files, or a repository.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.2.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-review-instruction an-dr-ai-use-user-interface an-dr-concept-ai-slop an-dr-files-build-report an-dr-convention-html-report
---

# Code and documentation coherence analysis

Defers: what slop is to `an-dr-concept-ai-slop`, agent instruction correctness to `an-dr-ai-review-instruction`, report format to `an-dr-convention-html-report`, building to `an-dr-files-build-report`, user messages to `an-dr-ai-use-user-interface`.

## Establish scope

1. Resolve the scope from the request and active task: uncommitted changes, commit or range, branch against base, selected files or directories, or whole repository. "Deslop the current work" → that work's changes.
1. Unspecified → never default to the whole repository; ask only when request and context do not identify it.
1. Branch diff → resolve and record the base and comparison method; ask if the base is ambiguous.
1. Read repository instructions, README, documentation index, and the selected material. Exclude generated output, vendored dependencies, and build artifacts unless explicitly in scope.
1. Record scope, refs or paths, date, and whether uncommitted changes were inspected.
1. Large scope → name the areas sampled and not inspected; never call a sample exhaustive.

## Examine

- Take the next maintainer's or user's view; produce recommendations, not fixes.
- Changes or branch diffs → report only problems introduced or worsened by them; read context to judge effects, without auditing the repository or blaming the change for pre-existing issues.
- Trace documented workflows to entry points, implementations, callers, and tests; read context before judging a fragment.
- Use existing checks or small read-only experiments to resolve uncertainty; distinguish checks run from suggested verification.
- Apply the cut, defence, and cost tests of `an-dr-concept-ai-slop` to code, text, agent-loaded instructions, and reports.
- A convention finding quotes the written rule it breaks, from host instructions or the governing convention skill, read first; an unquotable rule is a preference, not a finding.
- Name each finding's concrete cost to correctness, use, understanding, or maintenance; no taste-only rewrites, no quota filling.
- Check for a legitimate constraint or consumer before proposing removal.
- Group repeated instances of one cause into one finding with representative locations.

## Record findings

- IDs `DS-001`, `DS-002`, …; an ID stays with its issue across revisions and is never reused; resolved or withdrawn IDs stay in a quiet history section.
- Each finding: evidence with file and line or doc section, why it matters, a concrete proposed change.
- Basis: **confirmed** or **question**; a question names the missing evidence and how to resolve it, and phrases the change conditionally.
- For priorities, read [references/priorities.md](references/priorities.md).

## Write the report

Write one self-contained page in the `an-dr-convention-html-report` format at a `deslop` path with extension `html`, and build and publish it through `an-dr-files-build-report`, giving findings and counts their priority level. For sections and verification, read [references/page.md](references/page.md).

## Output

The HTML link or local path and a short summary of the most consequential findings. HTML only, never a Markdown substitute.

## Rules

- Source changes are a separately requested task under the repository's workflow.
