---
name: an-dr-agents-repo-modify
description: Change this workflow repository's instructions — AGENTS.md, roles, skills, scripts — from wherever the need appeared, summarize the change, and commit and push it once the user approves. Use for every change to this repository, whether requested here or while working in another repository.
license: MIT
allowed-tools: PowerShell Read Grep Glob Write Edit
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.2.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-agents-repo-convention-skills an-dr-agents-repo-install an-dr-agents-repo-verify-installation an-dr-ai-review-instruction an-dr-ai-send-message an-dr-ai-skill-implement-test an-dr-ai-skill-test an-dr-ai-write-instruction an-dr-convention-agent-skill an-dr-convention-markdown an-dr-convention-script an-dr-git-commit
---

# Modify the agents repository

Defers: rule writing to `an-dr-ai-write-instruction`, tests to `an-dr-ai-skill-implement-test` and `an-dr-ai-skill-test`, commits to `an-dr-git-commit`.

## Locate the clone

```powershell
pwsh <skill>/scripts/find-agents-root.ps1 [-Path <start-directory>] [-AgentsRoot <path>]
```

It checks the clone providing this skill (through a global install's junction), the working repository, an `agents` submodule in it, and each tool's `an-dr-agents-repo-install` policy path. It prints a candidate table, then the resolved root's branch, working tree, upstream, and whether it is nested in the host repository.

| Exit | Meaning                  | Do                                                                                                              |
| ---- | ------------------------ | --------------------------------------------------------------------------------------------------------------- |
| `0`  | one clone resolved       | work in the printed root                                                                                        |
| `1`  | no clone found           | ask where the clone is through `an-dr-ai-send-message`, re-run with `-AgentsRoot`                               |
| `2`  | several different clones | show the table, ask as an `an-dr-ai-send-message` question with one option per clone, re-run with `-AgentsRoot` |

- Report every printed note: detached HEAD, dirty tree, missing upstream, and nested clone each change the commit.
- Use the resolved root for every later path and every git call; git must run in the clone, not through a junction.

## Change it

1. Name the observed behavior with quoted evidence from the host repository or the request: what the agent did, which instruction caused it, what it should do. Without evidence it is a preference, and the user decides.
2. Edit with `an-dr-ai-write-instruction`; skill text follows `an-dr-convention-agent-skill`, format `an-dr-convention-markdown`.
3. Adding, renaming, or restructuring a skill follows `an-dr-convention-agent-skill` (format, folder, registration) and `an-dr-agents-repo-convention-skills` (names, metadata); scripts follow `an-dr-convention-script`. A new commit scope goes into the `AGENTS.md` scope list.
4. Find each rule stated more than once across the changed files and the files they touch. Keep a repeat only if it adds a point-specific detail (exact options, safe default) or sits where an agent would otherwise miss the rule; otherwise delete it or name its owner.
5. Read root `README.md` and `skills/README.md` against the diff; update every description of changed behavior (mode, phase, skill, command, layout) in the same change.
6. Use `an-dr-ai-skill-implement-test` for script test coverage and, for new or corrected behavior, behavior cases. After every modification run the affected skills' cheap script tests and validate changed case data with `an-dr-ai-skill-test`. Behavioral execution needs an explicit user request. Report unrun evaluations separately from script results and structural checks.
7. Run `pwsh <clone>/tests/run-all.ps1` (`<clone>` = resolved root) and fix everything it reports. For its scope, `-All`, the repository-wide checks, and a missing `skills-ref`, read [references/checks.md](references/checks.md).
8. A skill directory added, renamed, or removed → re-run `an-dr-agents-repo-install`'s `install-agents.ps1` and report its table.
9. A skill or policy file added, renamed, or moved → run `an-dr-agents-repo-verify-installation`.

## Summarize

Present before asking for anything; the summary is the deliverable even if no commit follows:

- every changed file, with the behavior it changes from and to;
- the evidence each change answers;
- what was left alone, including amendments considered and rejected;
- `git -C <root> diff --stat`, plus the full diff of the instruction files;
- the size report of `pwsh <skill>/scripts/size-diff.ps1 -Root <root>`; growth in what agents load needs a matching cut or a stated reason.

## Commit and push

Only after the user approves the summary in their own words; approval covers this change only.

1. Commit through `an-dr-git-commit` in the clone, on its current branch: no flow, no feature branch, no `.progress/`.
2. Push that branch.
3. Clone nested in the host → its gitlink moved. Follow the host's instructions for submodule pointers, committing through `an-dr-git-commit` when they say so; if they say nothing, leave it uncommitted and tell the user it waits in the host repository.

## Rules

- Before editing anything, explain the intended change and get approval as an `an-dr-ai-send-message` confirmation.
- Leave the host's work untouched: no phase advances, no host file edits, no host commit carries the amendment.
- Stage only this amendment's files; in an already dirty clone, ask rather than sweep other changes in.
- Never weaken or delete an existing rule as a side effect; that is a separate proposal with its own approval.
- One amendment is one commit; an unrelated change gets its own summary and approval.
