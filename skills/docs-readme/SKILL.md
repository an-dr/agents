---
name: docs-readme
description: Rewrite or update a repository's README from what the code actually contains — read the manifests, entry points, CI, tests, and docs first, then keep, reorder, cut, and add sections against that evidence. Use when a README is missing, stale, or disorganised, when it needs updating after a change, when a project needs one from scratch, or when the user wants the repository to read well to a newcomer.
allowed-tools: Read, Grep, Glob, Write, Edit, PowerShell
metadata:
  dependencies: agents-ui convention-markdown convention-readme docs-gif docs-screenshot docs-writing
---

# README

The README is the only document most readers will open. This skill edits it against the repository's own evidence: the code is ground truth, and the existing README is a claim about the code that may already be false.

Load `convention-markdown` before writing a line: its rules govern line breaks, lists, tables, and links in the README, including in sections left otherwise unchanged. Human-facing content principles come from `docs-writing`. What belongs in `docs/`, an ADR, or a design doc stays there and is linked, never summarised twice.

## Read the repository first

Never open the README first — read the evidence, then judge what the README says about it.

| Look at | Tells you |
| --- | --- |
| `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `*.csproj`, `pom.xml` | name, version, entry points, dependencies, whether it is a library or an application |
| `bin/`, `main.*`, `cmd/`, `[project.scripts]`, `"bin"` | it is a CLI, and what the command is called |
| `packages/`, `apps/`, workspace declarations | it is a monorepo and needs a repository map |
| `tests/`, `spec/`, `*_test.*` | a development section is honest |
| `.github/workflows/`, `.gitlab-ci.yml` | badges can be real, and how the project is built |
| `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` | which of those sections may exist at all |
| `docs/`, `docs/adr/` | link out instead of inlining |
| commit count and recency, CI presence | experimental or maintained — the status line is evidence, not a guess |

## Classify what is already there

A chaotic README usually suffers from redundancy, dead links, and bad order more than from missing content. Before writing, put every existing section in one bucket:

| Bucket | Meaning |
| --- | --- |
| keep | true, useful, already in the right place — carry it across unchanged, including its wording |
| rewrite | true but buried, bloated, or out of order |
| cut | false, duplicated elsewhere in the file, or dead |
| relocate | true and worth keeping, but at the wrong altitude — a specification belongs in the document that owns it, design detail in `design/`, implementation notes in the code's own doc comments. Move it and link, never both |
| missing | the baseline or a conditional module the evidence supports |

Cutting is work. A section removed for redundancy improves the README as much as one added.

Relocating is the one that goes wrong quietly. A README that restates a specification kept elsewhere drifts from it, and the copy readers reach first is the one that is wrong: check such a section against its owning document before deciding, because the discrepancy is usually already there.

## Write to the convention

Shape the README by `convention-readme`: its baseline order, conditional modules, and truth rules decide what stays, moves, or is added. Never fabricate; a missing fact becomes an open question. Capture screenshots with `docs-screenshot` and a GIF with `docs-gif` only when the user asks. A screenshot must show the project as it is now: recapture an outdated one, and when the project cannot be launched here, list the screenshot as an open question instead of skipping it silently.

## Check

```powershell
pwsh <convention-readme>/scripts/check-readme.ps1 -ConventionMarkdownSkill <convention-markdown> [-Path <repo>] [-Readme <file>]
```

Run it before writing to see the evidence and the existing file's faults, and again afterwards; deliver only once it exits zero.

## Output

Deliver the finished `README.md`, or a diff first when the user wants to review before it lands. Follow it with the open questions as one `agents-ui` round, each naming what could not be established from the repository.
