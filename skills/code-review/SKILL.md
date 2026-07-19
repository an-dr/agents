---
name: code-review
description: Review a diff for defects, security issues, structural problems, convention violations, and outdated patterns. Use during VERIFY on an increment diff, before MR on the full branch diff, or when the user requests a code review; record structured findings in REPO/code-review JSON and render Markdown through the bundled PowerShell scripts.
---

# Code review

Use JSON as the canonical review record. Never hand-edit the JSON or generated
Markdown; use the scripts so sections, stable IDs, and numbering remain valid.

## Select the diff

| Situation | Diff |
| --- | --- |
| VERIFY | Uncommitted increment changes, or the last commit when clean |
| MR | Full feature branch against its base |
| Requested | Range or codebase named by the user |

Review defects, security, structure, conventions, and modernization, in that
order. Every finding needs a tight file location and concrete recommendation.

## Create the review

From the repository being reviewed, run:

```powershell
pwsh <skill>/scripts/review-start.ps1 -Reference '<branch-or-ref>' -Scope verify
```

This creates `REPO/code-review/`, its `.gitignore`, and a schema-versioned JSON
record from `assets/review-template.json`. Commit only the `.gitignore`; review
state and rendered reports remain local unless the user explicitly requests
otherwise.

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

Finding sections are `critical`, `high`, and `improvement`; their IDs are
assigned as `CR.N`, `HI.N`, and `IM.N`. Positive notes use `PO.N`. Summary and
verdict are singleton sections and are updated rather than appended.

## Render and report

```powershell
pwsh <skill>/scripts/review-render.ps1 -ReviewPath <json>
```

The renderer always emits the fixed Markdown section order. Summarize critical
findings and the verdict in chat; keep the generated file as a local inspection
artifact.

Review only. Return fixes to BUILD, and never weaken tests or expand scope to
make the review pass.
