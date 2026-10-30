---
name: convention-readme
description: What a README contains and in what order — the baseline sections, the modules a repository's evidence justifies, and the rule that every statement is backed by the repository. Use when writing, reviewing, or checking a README; a rewrite procedure applies it.
metadata:
  dependencies: concept-ai-slop concept-evidence-grounding convention-markdown
---

# Convention: README

A README is the only document most readers open. This convention owns its shape and the rule that it is true. A separate procedure owns how to rewrite one from the repository's evidence. `check-readme.ps1` in this skill enforces what a script can. Markdown mechanics follow `convention-markdown`, and the content applies `concept-evidence-grounding`.

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
| Website, GUI application, or game | a screenshot near the top; a GIF only when the user asks for one |
| `docs/adr/` or non-trivial architecture | a link out, never an inlined summary |
| Known gaps | a short "not yet supported" section — it undersells slightly and earns trust |
| Community-facing | code of conduct, support channels, FAQ |

## Truth

The failure mode of a generated README is plausible filler, and it is worse than a thin README because it cannot be trusted.

- Apply `concept-ai-slop`: a section, badge, or feature bullet that fails its cut test is removed, and a feature list selects rather than inventories.
- No `LICENSE` file means no license section. Report the gap; do not name a license.
- No tests means no testing instructions. No CI means no build badge.
- Never invent a command, flag, environment variable, or module path. Every command in the README must exist in the repository.
- Where a fact is missing or ambiguous, it is an open question for the user, not a guess.
- A screenshot shows the project as it is now. Never keep or link an image whose subject the repository no longer contains.
- What belongs in `docs/`, an ADR, or a design doc stays there and is linked, never summarised twice.
- Keep the project's own voice where it has one.

## Check

```powershell
pwsh <skill>/scripts/check-readme.ps1 -ConventionMarkdownSkill <convention-markdown> [-Path <repo>] [-Readme <file>]
```

The script reports the evidence it found, then every claim the README makes that the repository does not support, every unresolved relative link, duplicated headings, missing baseline sections, and sections out of baseline order. It then runs `convention-markdown`'s checker on the README and prints its findings. It exits non-zero on a contradiction, a dead link, or a Markdown format error.
