---
name: an-dr-convention-artifact-layout
description: Where generated artifacts live — one folder per kind under .tmp-ai-gen, files named by kind and minute, a kind-latest copy at the root, only registered kinds, and deliverables kept out. Use when naming or reporting the path of any file a skill outputs that is not repository content; new-artifact-path.ps1 and publish-latest.ps1 in this skill create the paths.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "2.0.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: artifact layout

Generated artifacts are not repository content. Each kind has one folder whose files sort by time, and the newest of each kind has a fixed name at the root, so the user opens `code-review-latest.html` without hunting. The scripts in this skill are the only place that implements it.

```text
REPO/.tmp-ai-gen/
  .gitignore                                # holds * — git ignores the whole folder
  code-review-latest.json                   # copies of the newest code review
  code-review-latest.html
  change-report-latest.html
  code-review/
    code-review-2026-11-01_14-32.json
    code-review-2026-11-01_14-32.html
  change-report/
    change-report-2026-11-01_15-10.html
```

- A file is named `<kind>-<YYYY-MM-DD_hh-mm>.<extension>` inside its `<kind>/` folder. A second artifact in the same minute takes `-2`, `-3`, and so on after the minute.
- Files of one artifact share one stamp and differ only in extension, such as a review's `.json` and its rendered `.html`, or `questions.json` and `answers.json`.
- `<kind>-latest.<extension>` at the root of `.tmp-ai-gen/` is a copy of the newest finished artifact of that kind, not a link.
- `<kind>` must be registered in `assets/kinds.txt`. Only outputs a skill names go here: scratch files, test fixtures, browser profiles, and diffs go to the system temp directory and are deleted after use. A skill that needs a new kind adds it to that list in the same change.
- Deliverables are not artifacts and never go here: ADRs, READMEs, and documentation under `docs/` are committed as ordinary repository content.
- Commit nothing beneath `.tmp-ai-gen/`; its own `.gitignore` ignores the folder, so the repository needs no rule for it.
- Report the artifact's path to the user whenever one is written, because an artifact they cannot find is an artifact that did not happen.
- Never build a path by hand, in prose or in a script; take it from the scripts below.

## Take a path

```powershell
pwsh <skill>/scripts/new-artifact-path.ps1 -Kind <kind> -Extension <extension> [-Stamp <YYYY-MM-DD_hh-mm>] [-RepositoryRoot <path>]
```

It creates the kind folder and the `.gitignore`, then prints the file path. Without `-Stamp` it takes the current minute; pass the printed stamp as `-Stamp` for every other file of the same artifact. It rejects an unregistered kind, an uppercase extension, and a malformed stamp, so a mistyped path fails instead of scattering files.

## Publish the latest

```powershell
pwsh <skill>/scripts/publish-latest.ps1 -Path <artifact-file>
```

Run it once the artifact is complete. It replaces every `<kind>-latest.*` file with copies of all files sharing the artifact's stamp, and prints the copies. Report the latest path to the user alongside the stamped one.
