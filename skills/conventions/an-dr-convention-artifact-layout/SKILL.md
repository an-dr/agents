---
name: an-dr-convention-artifact-layout
description: Where generated artifacts live — one folder per kind under .tmp-ai-gen, kind-and-minute file names, each kind declared by the one skill that writes it, an optional kind-latest copy, an other folder for user-requested outputs no kind fits, deliverables kept out. Use when naming, placing, or reporting a non-repository output file.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "2.1.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: artifact layout

## Layout

- A file is `<kind>/<kind>-<YYYY-MM-DD_hh-mm>.<extension>` under `.tmp-ai-gen/`; a second artifact in the same minute appends `-2`, `-3`, ... after the minute.
- Files of one artifact share one stamp and differ only in extension (a review's `.json` and `.html`; `questions.json` and `answers.json`).
- `<kind>` is declared by the skill that writes it, in its `an-dr.artifact.kind` metadata; a skill writes at most one kind, one skill owns each kind, and this convention keeps no list of them.
- A kind whose skill sets `an-dr.artifact.internal: true` is state that skill keeps for itself, not output for the user: it lives in `.internal/<kind>/` under `.tmp-ai-gen/`, named the same way, and has no latest copy.
- A kind whose skill sets `an-dr.artifact.pin-latest: true` has `<kind>-latest.<extension>` at the root of `.tmp-ai-gen/`: a copy, not a link, of the newest finished artifact of that kind. Any other kind has no latest copy.
- An output the user asks for that no declared kind fits, such as a custom report, is `other/<YYYY-MM-DD_hh-mm>-<name>.<extension>`, where `<name>` is lowercase hyphenated words; `other` has no latest copy, and a skill that writes the same output repeatedly declares its own kind instead.
- Only outputs a skill names go here; scratch files, test fixtures, browser profiles, and diffs go to the system temp directory and are deleted after use.
- Deliverables never go here: ADRs, READMEs, and `docs/` are committed repository content.
- Nothing beneath `.tmp-ai-gen/` is committed; its own `.gitignore` (`*`) ignores it, so the repository needs no rule.
- Every written artifact is reported to the user by its path; one they cannot find did not happen.
- Every path is produced by a script that applies this layout, never built by hand in prose or a script.

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
  .internal/
    ui-session/
      ui-session-2026-11-22_14-05.questions.json      # a skill's own working state
```
