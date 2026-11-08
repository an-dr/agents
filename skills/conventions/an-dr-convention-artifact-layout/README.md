# an-dr-convention-artifact-layout

Where generated outputs live — code reviews, change reports, overviews — so you always know where to find the latest one and none of them reaches git.

## When it runs

A convention is read, never run. Every skill that writes a non-repository output takes its path from `scripts/new-artifact-path.ps1` and refreshes the latest copy with `scripts/publish-latest.ps1`.

## How it works

```text
REPO/.tmp-ai-gen/
  .gitignore                          # "*" — git ignores the whole folder
  code-review-latest.html             # copy of the newest code review
  change-report-latest.html
  code-review/
    code-review-2026-11-01_14-32.json
    code-review-2026-11-01_14-32.html
  change-report/
    change-report-2026-11-01_15-10.html
```

- One folder per registered kind, files named by kind and minute; files of one artifact share the stamp.
- `<kind>-latest.*` at the top is a copy of the newest finished artifact.
- Scratch files and fixtures go to the system temp directory instead. Deliverables — ADRs, READMEs, `docs/` — are committed content and never go here.
- A kind must be registered in `assets/kinds.txt` before a skill can write it.

## What you get

Every artifact is reported by its path, and "latest" is always one predictable filename.

## Related skills

- [an-dr-files-build-report](../../actions/an-dr-files-build-report/README.md) — takes paths and publishes reports.
- [an-dr-convention-html-report](../an-dr-convention-html-report/README.md) — the page format.
