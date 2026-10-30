---
name: an-dr-convention-artifact-layout
description: Where generated artifacts live — one run directory per day and letter under .artifacts, one subdirectory per kind, a single committed .gitignore, and deliverables kept out. Use when naming or reporting the path of any file that is not repository content; new-artifact-dir.ps1 in this skill creates the directories.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: artifact layout

Generated artifacts are not repository content. They live in one directory per run, so the user opens the newest directory and finds everything that run produced, however long it took. `new-artifact-dir.ps1` in this skill is the only place that implements it.

```text
REPO/.artifacts/
  .gitignore                      # * and !.gitignore — commit this one file
  ai-2026-10-18-A/                # the day's first run
    code-review/<id>.review.json
    code-review/<id>.review.html
    reports/<short-name>.html
  ai-2026-10-18-B/                # the next run
    overview/project-overview.html
```

- `ai-<YYYY-MM-DD>-<N>`, where `<N>` is a letter naming the run: `A` for the day's first, then `B`, and `AA` after `Z`. One run owns one letter whatever it produces.
- `<kind>` is the artifact's kind in lowercase words joined by hyphens: `code-review`, `reports`, `overview`, or a new one a skill needs. `.artifacts` ignores everything beneath it, so a new kind never needs an ignore rule.
- Take a letter once per run and reuse that stamp for every later artifact of the same run. A second letter means a second run, not a second file.
- A path that already exists is reused as it is, so a step that reruns overwrites its own output instead of multiplying directories.
- Deliverables are not artifacts and never go here: ADRs, READMEs, and documentation under `docs/` are committed as ordinary repository content.
- Commit `.artifacts/.gitignore` and nothing else beneath `.artifacts`.
- Report the artifact's path to the user whenever one is written, because an artifact they cannot find is an artifact that did not happen.
- Never build the directory name by hand, in prose or in a script; take it from the script below.

## Take a directory

```powershell
pwsh <skill>/scripts/new-artifact-dir.ps1 -Kind <kind> [-Run <YYYY-MM-DD>-<N>] [-RepositoryRoot <path>]
```

It creates the directory and the `.gitignore` above it, then prints the path. Without `-Run` it takes the day's next free letter; with `-Run` it uses exactly that run, creating it when needed. It rejects a kind that is not lowercase and a stamp that is not a date and a letter, so a mistyped path fails instead of scattering artifacts. Pass the printed stamp to every later artifact of the same run, and report the path to the user.
