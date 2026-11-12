---
name: an-dr-dev-integrate
description: Integrate an approved work branch into the default branch through its pull or merge request with the repository's merge method, or locally by rebasing and keeping, regrouping, or squashing its commits when no platform is available. Use for the draft request at a work branch's first push, for review comments, and after the integration gate.
license: MIT
allowed-tools: PowerShell
metadata:
  author: Andrei Gramakov (an-dr)
  version: "2.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-use-user-interface an-dr-convention-commit-message an-dr-git-modify-history
---

# Integrate

Defers: questions to `an-dr-ai-use-user-interface`; messages to `an-dr-git-modify-history`, checked by `an-dr-convention-commit-message`.

## Through the request

Spec-driven and Supervised branches integrate through their pull or merge request whenever the platform allows it. Read [references/pull-request.md](references/pull-request.md) at the first push, when the user says to address the comments, and at integration.

## Ask the local mode

Only when the request path is unavailable, and after saying what is missing. Before asking, read [references/modes.md](references/modes.md).

- Ask every time, as the first step, before progress cleanup, rebase, or any history change; never answer it yourself.
- Approval to integrate is not a mode choice; the last mode used is not a default.
- One `an-dr-ai-use-user-interface` question, the three local modes as options (`Commits`, `Regroup`, `Squash`), no recommendation; wait for the answer.

## Run the steps

Scripts are in `<skill>/scripts/`; each exits non-zero on failure. `<an-dr-convention-commit-message>` is that convention's folder, wherever it was loaded from; scripts take it as a parameter instead of guessing.

| Step                                  | Command                                                                                                                                                                   |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0 — remove progress                   | `pwsh remove-progress.ps1 [-BaseBranch <name>]`                                                                                                                           |
| 1 — check state                       | `pwsh integrate-1-check.ps1 [-BaseBranch <name>]`                                                                                                                         |
| 2 — squash commits (optional)         | `pwsh integrate-2-squash.ps1 -Hash <hash> -Message '<msg>' -CommitMessageSkill <an-dr-convention-commit-message> [-BaseBranch <name>]`                                    |
| 2 — regroup commits (`Regroup` only)  | `pwsh integrate-2-regroup.ps1 -Plan <plan.json> -CommitMessageSkill <an-dr-convention-commit-message> [-BaseBranch <name>]`                                               |
| 3 — rebase                            | `pwsh integrate-3-rebase.ps1 [-BaseBranch <name>]`                                                                                                                        |
| 4 — finish                            | `pwsh integrate-4-finish.ps1 -Mode <Commits\|Squash\|Request\|RebaseMerge> [-Message '<msg>' -CommitMessageSkill <an-dr-convention-commit-message>] [-BaseBranch <name>]` |
| 5 — rebase-merge (`RebaseMerge` only) | `pwsh integrate-5-rebase-merge.ps1 -TestedCommit <sha> [-BaseBranch <name>]`                                                                                              |

1. Run step 0 after the mode answer and after the workflow's `finish` operation and its deletion commit. The branch must be linear and the tree clean. It rewrites only commits after the merge base with the default branch: removes `.progress/` from each, keeps message, author, committer, and dates, prunes progress-only commits, and verifies neither final tree nor branch history holds `.progress/`. Rerun relevant tests if rewritten commits were not verified at their final content.
2. Run step 1. Check the recent log for WIP commits and the base-to-HEAD log for topic commits; it rejects remaining progress history.
3. WIP commits at the tip → step 2 squash, `<hash>` = the commit before the first WIP, with a clean message.
4. Run step 3 (fetch + rebase); fix conflicts where it pauses.
5. Run step 1 again, then:
   - `Commits` → step 4 `-Mode Commits`.
   - `Squash`, `Request` → step 4 with `-Message`; it collapses itself, step 2 is not rerun. Compose the message with `an-dr-git-modify-history`; it is validated before anything is rewritten.
   - `Regroup` → read [references/regroup.md](references/regroup.md), then step 4 `-Mode Commits`.
   - `RebaseMerge` → read [references/rebase-merge.md](references/rebase-merge.md).

## Interactive script

For a human: `pwsh <skill>/scripts/integrate.ps1 -CommitMessageSkill <an-dr-convention-commit-message>`; it asks the mode and refuses to proceed without an answer.

## Rules

- Local modes always rebase first and never add a merge commit; the request path uses the repository's configured merge method, merge commits included.
- `integrate-4-finish.ps1` makes `-Mode` mandatory so no run skips the question.
