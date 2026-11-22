---
name: an-dr-convention-artifact-layout
description: Where generated artifacts live — one folder per kind under .tmp-ai-gen, kind-and-minute file names, kind-latest copy, registered kinds only, an other folder for user-requested outputs no kind fits, deliverables kept out. Use when naming or reporting a non-repository output file; new-artifact-path.py and publish-latest.py in this skill create the paths.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "2.2.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: artifact layout

## Layout

- A file is `<kind>/<kind>-<YYYY-MM-DD_hh-mm>.<extension>` under `.tmp-ai-gen/`; a second artifact in the same minute appends `-2`, `-3`, ... after the minute.
- Files of one artifact share one stamp and differ only in extension (a review's `.json` and `.html`; `questions.json` and `answers.json`).
- `<kind>-latest.<extension>` at the root of `.tmp-ai-gen/` is a copy, not a link, of the newest finished artifact of that kind.
- `<kind>` is registered in `assets/kinds.txt`; a new kind is added in the same change as the skill that writes it.
- An output the user asks for that no registered kind fits, such as a custom report, is `other/<YYYY-MM-DD_hh-mm>-<name>.<extension>`, where `<name>` is lowercase hyphenated words; `other` has no latest copy, and a skill that writes the same output repeatedly registers its own kind instead.
- Only outputs a skill names go here; scratch files, test fixtures, browser profiles, and diffs go to the system temp directory and are deleted after use.
- Deliverables never go here: ADRs, READMEs, and `docs/` are committed repository content.
- Nothing beneath `.tmp-ai-gen/` is committed; its own `.gitignore` (`*`) ignores it, so the repository needs no rule.
- Every written artifact is reported to the user by its path; one they cannot find did not happen.
- Every path comes from `new-artifact-path.py`, never built by hand in prose or a script.

## Scripts

- `scripts/new-artifact-path.py` creates the kind folder and its `.gitignore` and prints the path for a kind, an extension, an optional stamp, and the name an `other` artifact requires; it rejects an unregistered kind, a missing or malformed `other` name, a name on any other kind, an uppercase extension, and a malformed stamp.
- `scripts/publish-latest.py` replaces every `<kind>-latest.*` file with copies of all files sharing an artifact's stamp and prints the copies; it refuses an `other` artifact.

## Examples

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
  other/
    2026-11-22_14-05-plugin-comparison.html   # a custom report; no latest copy
```
