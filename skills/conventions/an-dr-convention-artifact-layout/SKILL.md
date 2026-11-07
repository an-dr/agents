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
- `<kind>` must be registered in `assets/kinds.txt`. Only outputs a skill names go here: scratch files, test fixtures, browser profiles, and diffs go to the system temp directory and are deleted after use. A new kind is added to that list in the same change as the skill that writes it.
- Deliverables are not artifacts and never go here: ADRs, READMEs, and documentation under `docs/` are committed as ordinary repository content.
- Nothing beneath `.tmp-ai-gen/` is committed; its own `.gitignore` ignores the folder, so the repository needs no rule for it.
- Every written artifact is reported to the user by its path, because an artifact they cannot find is an artifact that did not happen.
- Every path comes from `new-artifact-path.ps1`; none is built by hand, in prose or in a script.

## Scripts

- `scripts/new-artifact-path.ps1` creates the kind folder and its `.gitignore` and prints the path for a kind, an extension, and an optional stamp. It rejects an unregistered kind, an uppercase extension, and a malformed stamp, so a mistyped path fails instead of scattering files.
- `scripts/publish-latest.ps1` replaces every `<kind>-latest.*` file with copies of all files sharing an artifact's stamp, and prints the copies.
