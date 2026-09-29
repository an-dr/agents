---
name: dev-code-review
description: Review a diff for defects, security issues, structural problems, convention violations, and outdated patterns. Use during Direct review, VERIFY on an increment diff, SUMMARY on the full branch diff, or when the user requests a code review; record structured findings in REPO/.artifacts/code-review JSON and render Markdown through the bundled PowerShell scripts.
---

# Code review

Use JSON as the canonical review record. Never hand-edit the JSON or generated Markdown; use the scripts so sections, stable IDs, and numbering remain valid.

## Select the diff

| Situation | Diff |
| --- | --- |
| Direct | Uncommitted changes for the request |
| VERIFY | Uncommitted increment changes, or the last commit when clean |
| SUMMARY | Full feature branch against its base |
| Requested | Range or codebase named by the user |

Review defects, security, structure, ergonomics, the host repository's stated conventions, and modernization, in that order. Every finding needs a tight file location and concrete recommendation. Writing preferences are not findings.

Ergonomics means the code is pleasant for a human to use and to read. Check that public interfaces are obvious to call correctly and hard to call wrongly, that names say what they do, that control flow can be followed top to bottom without holding hidden state in mind, and that a reader unfamiliar with the change can understand it from the code and its inline docs alone. Code that only a machine or its author can read is a finding, even when it is correct.

Check each item as a finding only when it costs the next reader or change: a unit doing several jobs, a stale or obvious comment, a public interface without useful documentation, duplicated facts, swallowed errors, dead code, or options nothing calls. Find defects, scope errors, and missing tests or docs; do not report mere differences of taste. Host conventions override general preferences.

## Create the review

From the repository being reviewed, run:

```powershell
pwsh <skill>/scripts/review-start.ps1 -Reference '<branch-or-ref>' -Scope <direct|verify|summary|requested>
```

This creates `REPO/.artifacts/code-review/`, its `.gitignore`, and a schema-versioned JSON record from `assets/review-template.json`. The directory ignores itself, so review state and rendered reports stay local unless the user explicitly requests otherwise.

## Record sections

Use `review-note.ps1` for every change:

```powershell
pwsh <skill>/scripts/review-note.ps1 -ReviewPath <json> `
  -Section critical -File src/app.ps1 -Line 42 `
  -Text '<problem>' -Recommendation '<concrete fix>'

pwsh <skill>/scripts/review-note.ps1 -ReviewPath <json> `
  -Section summary -Text '<summary>'

pwsh <skill>/scripts/review-note.ps1 -ReviewPath <json> `
  -Section verdict -Decision changes-required -Text '<rationale>'
```

Finding sections are `critical`, `high`, and `improvement`; their IDs are assigned as `CR.N`, `HI.N`, and `IM.N`. Positive notes use `PO.N`. Summary and verdict are singleton sections and are updated rather than appended.

## Render and report

```powershell
pwsh <skill>/scripts/review-render.ps1 -ReviewPath <json>
```

The renderer always emits the fixed Markdown section order. Summarize critical findings and the verdict in chat; keep the generated file as a local inspection artifact.

Review only. Return fixes to BUILD in gated flows or to Direct implementation, and never weaken tests or expand scope to make the review pass.
