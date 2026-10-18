---
name: artifact-storage
description: Decide where a generated artifact is written — code reviews, HTML reports, project overviews, scratch analysis — and create its run directory. Use before writing any file that is not repository content, and whenever an artifact path must be named to the user.
---

# Artifact storage

Generated artifacts are not repository content. They live in one directory per run, so the user opens the newest directory and finds everything that run produced, however long it took.

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
- Deliverables are not artifacts and never go here: ADRs, READMEs, and documentation under `docs/` are committed as ordinary repository content.

## Take a directory

```powershell
pwsh <skill>/scripts/new-artifact-dir.ps1 -Kind <kind> [-Run <YYYY-MM-DD>-<N>] [-RepositoryRoot <path>]
```

It creates the directory and the `.gitignore` above it, then prints the path. Without `-Run` it takes the day's next free letter; with `-Run` it uses exactly that run, creating it when needed. It rejects a kind that is not lowercase and a stamp that is not a date and a letter, so a mistyped path fails instead of scattering artifacts.

Take a letter once per run and pass that stamp to every later artifact of the same run, so one directory holds the run's review, report, and overview. Reuse is the normal case: a second letter means a second run, not a second file.

A path that already exists is reused as it is, so a step that reruns overwrites its own output instead of multiplying directories.

## Rules

- Never build the directory name by hand, in prose or in a script: the script is the only place the layout is implemented, and `AGENTS.md`'s Temporary artifacts rule is the only place it is stated.
- Report the artifact's path to the user whenever one is written, because an artifact they cannot find is an artifact that did not happen.
- Commit `.artifacts/.gitignore` and nothing else beneath `.artifacts`.
