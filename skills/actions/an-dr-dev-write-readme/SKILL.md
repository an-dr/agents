---
name: an-dr-dev-write-readme
description: Rewrite or update a repository's README from the evidence in its code, manifests, CI, tests, and docs. Use when a README is missing, stale, or disorganised, needs updating after a change, or should read well to a newcomer.
license: MIT
allowed-tools: Read Grep Glob Write Edit PowerShell
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.2.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message an-dr-dev-assign-ai-level an-dr-convention-markdown an-dr-convention-readme an-dr-dev-write-documentation an-dr-files-make-screengif an-dr-files-make-screenshot
---

# README

Defers: Markdown mechanics to `an-dr-convention-markdown`, content and order to `an-dr-convention-readme`, content principles to `an-dr-dev-write-documentation`, AI disclosure to `an-dr-dev-assign-ai-level`, media to `an-dr-files-make-screenshot` and `an-dr-files-make-screengif`.

## Read the repository first

1. Load `an-dr-convention-markdown` before writing; it governs every section, including unchanged ones.
1. Run the check below to see the evidence and the existing file's faults.
1. Read the evidence before the README; the code is ground truth, the README a claim that may be false. For what each file tells you, read [references/evidence.md](references/evidence.md).

## Classify what is already there

Put every existing section in one bucket: keep, rewrite, cut, relocate, or missing. For the buckets and relocation checks, read [references/buckets.md](references/buckets.md).

## Write to the convention

- Shape by `an-dr-convention-readme`: baseline order, conditional modules, truth rules.
- Never fabricate; a missing fact becomes an open question.
- Content owned by `docs/`, an ADR, or a design doc stays there and is linked, never summarised twice.
- Screenshot or GIF only when the user asks; a screenshot shows the project as it is now — recapture an outdated one; project cannot launch here → open question, never a silent skip.

## Disclose AI usage

After writing, run `an-dr-dev-assign-ai-level`, unless the user declined earlier in the session.

## Check

```powershell
pwsh <an-dr-convention-readme>/scripts/check-readme.ps1 -MarkdownSkill <an-dr-convention-markdown> [-Path <repo>] [-Readme <file>]
```

Run before writing and again after; deliver only once it exits zero.

## Output

- The finished `README.md`, or a diff or plan first when the user wants to review; a plan names the same command the README would.
- Either form gives the exact command to run — `python exporter.py` or the installed console script — with its expected input; mark a command you could not run as unverified. A quickstart without that command is not a deliverable.
- Then the open questions as one `an-dr-ai-send-message` round, each naming what the repository could not establish.
