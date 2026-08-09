---
name: docs-readme
description: Rewrite a repository's README from what the code actually contains — read the manifests, entry points, CI, tests, and docs first, then keep, reorder, cut, and add sections against that evidence. Use when a README is missing, stale, or disorganised, when a project needs one from scratch, or when the user wants the repository to read well to a newcomer.
allowed-tools: Read, Grep, Glob, Write, Edit, PowerShell
---

# README

The README is the only document most readers will open. This skill edits it against the repository's own evidence: the code is ground truth, and the existing README is a claim about the code that may already be false.

Markdown mechanics come from `docs-md-writing`. The role is `tech-writer`. What belongs in `docs/`, an ADR, or a design doc stays there and is linked, never summarised twice.

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
| missing | the baseline or a conditional module the evidence supports |

Cutting is work. A section removed for redundancy improves the README as much as one added.

## Baseline structure

In this order, every time:

1. Title and a one-line description of what it is — not a tagline.
2. Badges, only where they are accurate. A stale or broken badge is worse than none.
3. Why it exists and what it solves, in two to four sentences.
4. Table of contents, only past roughly four screens.
5. Installation — copy-pasteable commands with no prose between them.
6. Quickstart — one realistic example of the primary use, not a hello-world, if the project has an obvious main job.
7. Features — five to ten scannable bullets, not an inventory.
8. Configuration — the common knobs only, linking out for the rest.
9. Documentation — a pointer to `docs/`, the wiki, or the ADRs.
10. Contributing — one line is enough signal.
11. License.
12. Status — actively maintained, experimental, or archived. Readers weight this heavily.

## Conditional modules

Add one only where the repository shows the signal.

| Signal | Add |
| --- | --- |
| CLI tool | the command and flag reference, or the generated `--help` output |
| Library or package | an API summary, or a link to the generated documentation |
| Tests present | a development section: how to run the tests and build from source |
| Monorepo | a repository map of what lives where |
| Visible output | a screenshot or GIF near the top |
| `docs/adr/` or non-trivial architecture | a link out, never an inlined summary |
| Known gaps | a short "not yet supported" section — it undersells slightly and earns trust |
| Community-facing | code of conduct, support channels, FAQ |

## Never fabricate

The failure mode of a generated README is plausible filler, and it is worse than a thin README because it cannot be trusted.

- No `LICENSE` file means no license section. Report the gap; do not name a license.
- No tests means no testing instructions. No CI means no build badge.
- Never invent a command, flag, environment variable, or module path. Every command in the README must exist in the repository.
- Where a fact is missing or ambiguous, it goes to the user as an open question. Ending with three open questions beats filling three gaps with guesses.

Keep the project's own voice where it has one. The goal is this project's README done well, not a template with the nouns replaced.

## Check

```powershell
pwsh agents/skills/docs-readme/scripts/check-readme.ps1 [-Path <repo>] [-Readme <file>]
```

The script reports the evidence it found, then every claim the README makes that the repository does not support, every unresolved relative link, duplicated headings, missing baseline sections, and sections out of baseline order. It exits non-zero on a contradiction or a dead link. Run it before writing to see the evidence and the existing file's faults, and again afterwards. Then run `docs-md-writing`'s checker for the format.

## Output

Deliver the finished `README.md`, or a diff first when the user wants to review before it lands. Follow it with the open questions, each naming what could not be established from the repository.
