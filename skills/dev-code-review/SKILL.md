---
name: dev-code-review
description: Review a diff for defects, security issues, structural problems, convention violations, and outdated patterns. Use during Direct review, VERIFY on an increment diff, SUMMARY on the full branch diff, or when the user requests a code review; record structured findings in the run's code-review JSON and render an HTML report through the bundled PowerShell scripts.
metadata:
  requires: artifact-storage docs-html-report ui-dark-cockpit
---

# Code review

Use JSON as the canonical review record. Never hand-edit the JSON or the generated HTML; use the scripts so sections, stable IDs, and numbering remain valid.

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

Review architecture and reviewability against `dev-build`'s Architecture, Names and structure, and Reviewable changes sections. Report as findings: dependencies pointing outward, a lifecycle held as scattered flags, a unit that gained a second responsibility, coupling to another component's private internals, a boundary format built outside the shared codec, optional members every implementation provides, names that describe a previous design or reuse one name for two concepts, structure or names an experienced developer in that ecosystem would not expect, stale references to removed code, and a missing ADR for a new public contract or ADR exception. Also judge the shape of the diff itself: formatting-only and mechanical changes mixed into behaviour changes are a finding, and a SUMMARY branch whose commits cannot each be reviewed and bisected as one concern is `high`.

## Create the review

From the repository being reviewed, run:

```powershell
pwsh <skill>/scripts/review-start.ps1 -Reference '<branch-or-ref>' -Scope <direct|verify|summary|requested> -ArtifactStorageSkill <artifact-storage>
```

This takes a `code-review` directory from `artifact-storage` and writes a schema-versioned JSON record into it from `assets/review-template.json`. Review state and rendered reports stay local there unless the user explicitly requests otherwise.

Pass `-Run <YYYY-MM-DD>-<N>` to put the review in a run directory this run already has, so its review, change report, and overview sit together instead of taking a second letter. Every later step reads the run directory from the JSON path it is given, so findings and the rendered page stay together across midnight and across later runs.

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

A finding may carry one Mermaid diagram through `-Diagram '<source>'` or `-DiagramPath <file>`. Attach one when the problem is structural and a picture explains it faster than prose: a dependency pointing the wrong way, a request or handoff flow that goes wrong, a lifecycle with a missing transition, unclear ownership. Do not attach one to a line-level defect. Draw only what the code shows, and follow `docs-html-report` for the diagram type and format.

## Render and report

```powershell
pwsh <skill>/scripts/review-render.ps1 -ReviewPath <json> -HtmlReportSkill <docs-html-report> -DarkCockpitSkill <ui-dark-cockpit>
```

The renderer writes one self-contained `.html` page beside the JSON, in a fixed section order: verdict, summary, critical, high, improvements, positives, and renders diagrams offline through `docs-html-report`'s embed script. HTML is the only rendered format; do not produce a Markdown review. The page follows `ui-dark-cockpit`: critical findings are red, high amber, improvements unhued, and positives dimmed and collapsed. Summarize critical findings and the verdict in chat by the same skill's text rules, and give the path of the HTML file; keep it as a local inspection artifact.

Review only. Return fixes to BUILD in gated flows or to Direct implementation, and never weaken tests or expand scope to make the review pass.
