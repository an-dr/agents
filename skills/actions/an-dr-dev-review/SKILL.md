---
name: an-dr-dev-review
description: Review a diff for defects, security issues, structure, convention violations, and outdated patterns, recording findings in a JSON record rendered to HTML. Use on a change, on a whole branch against its base, or when the user requests a code review.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-use-user-interface an-dr-concept-ai-slop an-dr-concept-clean-dependencies an-dr-concept-evidence-grounding an-dr-convention-artifact-layout an-dr-convention-code an-dr-convention-html-repo-style an-dr-convention-html-report an-dr-convention-layout
---

# Code review

Defers: structure and dependencies to `an-dr-concept-clean-dependencies`, evidence to `an-dr-concept-evidence-grounding`, slop to `an-dr-concept-ai-slop`, report format to `an-dr-convention-html-report`.

## Select the diff

| Situation      | Diff                                               |
| -------------- | -------------------------------------------------- |
| A change       | Uncommitted changes, or the last commit when clean |
| A whole branch | The branch against its base                        |
| Requested      | Range or codebase named by the user                |

## Judge

- Order: defects, security, structure, ergonomics, host conventions, modernization.
- Every finding: tight file location and concrete recommendation.
- Report defects, scope errors, missing tests or docs; not writing preferences or taste.
- Host conventions override general preferences.
- For ergonomics, reader cost, and architecture findings, read [references/checklist.md](references/checklist.md).

Judge placement of added files and folders by `an-dr-convention-layout` and its reference for the project type:

```sh
python <an-dr-convention-layout>/scripts/check-layout.py --path <repository>
```

Prints one row per layout finding; exit `1` on any error. Error in a path the diff adds or moves → finding; errors elsewhere → summary, as existing layout debt.

## Create the review

From the reviewed repository:

```sh
python <skill>/scripts/review-start.py --reference '<branch-or-ref>' \
  --scope <direct|verify|summary|requested> \
  --artifact-layout-skill <an-dr-convention-artifact-layout>
```

Takes a `code-review` path from `an-dr-convention-artifact-layout` and writes a schema-versioned JSON record there from `assets/review-template.json`. Review state and reports stay local unless the user asks otherwise.

## Judge for slop

- Apply `an-dr-concept-ai-slop` to added lines: comments restating code, options or layers with no consumer, prose padding and decoration, unchecked names, paths, or commands, template residue.
- Each confirmed instance → its own `slop` section, never among improvements, with the line and its cost to a reader; priority `high`.
- Item that also hides a defect or wrong claim → `critical` or `high` finding instead.
- Deeper coherence analysis is a separate request.

## Record sections

Use `review-note.py` for every change:

```sh
python <skill>/scripts/review-note.py --review-path <json> \
  --section critical --file src/app.py --line 42 \
  --text '<problem>' --recommendation '<concrete fix>'

python <skill>/scripts/review-note.py --review-path <json> \
  --section summary --text '<summary>'

python <skill>/scripts/review-note.py --review-path <json> \
  --section verdict --decision changes-required --text '<rationale>'
```

- Finding sections `critical`, `high`, `slop`, `improvement` get IDs `CR.N`, `HI.N`, `SL.N`, `IM.N`; positives `PO.N`.
- Summary and verdict are singletons, updated rather than appended.
- Before attaching a diagram with `--diagram` or `--diagram-path`, read [references/checklist.md](references/checklist.md).

## Render and report

```sh
python <skill>/scripts/review-render.py --review-path <json> \
  --html-report-skill <an-dr-convention-html-report> \
  --html-style-skill <an-dr-convention-html-repo-style> \
  --artifact-layout-skill <an-dr-convention-artifact-layout>
```

Writes one self-contained `.html` beside the JSON, copies both to `code-review-latest.*`, orders sections verdict, summary, critical, high, slop, improvements, positives, and renders diagrams offline through `an-dr-convention-html-report`'s embed script.

- HTML only; no Markdown review.
- In chat: critical findings and verdict by `an-dr-ai-use-user-interface`'s text levels, plus paths of the HTML and its latest copy; a local inspection artifact.

## Rules

- JSON is the canonical record; never hand-edit it or the HTML, so sections, IDs, and numbering stay valid.
- Judge by reading the diff; build or run tests only on user request; report missing coverage as a finding.
- Return fixes to implementation.
- Never weaken tests or expand scope to make the review pass.
