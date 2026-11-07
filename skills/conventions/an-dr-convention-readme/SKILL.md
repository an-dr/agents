---
name: an-dr-convention-readme
description: What a README contains and in what order — the baseline sections, the modules a repository's evidence justifies, and the rule that every statement is backed by the repository. Use when writing, reviewing, or checking a README.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: convention
  an-dr.dependencies: an-dr-concept-ai-slop an-dr-concept-evidence-grounding an-dr-convention-markdown
---

# Convention: README

Owns: README shape and truth. Defers: rewrite procedure to a separate action; Markdown mechanics to `an-dr-convention-markdown`; content grounding to `an-dr-concept-evidence-grounding`.

## Baseline structure

In this order, every time:

1. Title and a one-line description of what it is, not a tagline.
2. Badges, only where accurate; a stale or broken badge is worse than none.
3. Why it exists and what it solves, two to four sentences.
4. Table of contents, only past roughly four screens.
5. Installation: copy-pasteable commands, no prose between them.
6. Quickstart: one realistic example of the primary use, not a hello-world, when the project has an obvious main job.
7. Features: five to ten scannable bullets, not an inventory.
8. Configuration: common knobs only, linking out for the rest.
9. Documentation: a pointer to `docs/`, the wiki, or the ADRs.
10. Contributing: one line.
11. License.
12. Status: actively maintained, experimental, or archived; readers weight it heavily.

## Conditional modules

Present only where the repository shows the signal.

| Signal                                  | Add                                                                          |
| --------------------------------------- | ---------------------------------------------------------------------------- |
| CLI tool                                | the command and flag reference, or the generated `--help` output             |
| Library or package                      | an API summary, or a link to the generated documentation                     |
| Tests present                           | a development section: how to run the tests and build from source            |
| Monorepo                                | a repository map of what lives where                                         |
| Website, GUI application, or game       | a screenshot near the top; a GIF only when the user asks for one             |
| `docs/adr/` or non-trivial architecture | a link out, never an inlined summary                                         |
| Known gaps                              | a short "not yet supported" section — it undersells slightly and earns trust |
| Community-facing                        | code of conduct, support channels, FAQ                                       |

## Truth

- A section, badge, or feature bullet failing the `an-dr-concept-ai-slop` cut test is absent; a feature list selects, not inventories.
- No `LICENSE` file → no license section; the gap is reported and no license named.
- No tests → no testing instructions; no CI → no build badge.
- No invented command, flag, environment variable, or module path; every command exists in the repository.
- A missing or ambiguous fact is an open question for the user, not a guess.
- A screenshot shows the project as it is now; no image whose subject the repository no longer contains.
- Content belonging in `docs/`, an ADR, or a design doc stays there and is linked, never summarised twice.
- The project's own voice is kept where it has one.

## Check

`scripts/check-readme.ps1` reports the evidence found, every README claim the repository does not support, unresolved relative links, duplicated headings, missing baseline sections, and sections out of order; then runs the `an-dr-convention-markdown` checker on the README. Exits non-zero on a contradiction, a dead link, or a Markdown format error.
