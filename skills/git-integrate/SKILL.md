---
name: git-integrate
description: Integrate an approved feature branch into the default branch in one of three modes — keep the commits, squash into one commit, or open a request. Use after the integration gate; it removes workflow progress, rebases, applies the chosen mode, and cleans up the branch.
allowed-tools: PowerShell
---

# Integrate

Integration always rebases first, so the default branch never gains a merge commit from this skill. What happens after the rebase is the user's choice between three modes.

## The mode question

Ask it every time, before any mode-specific step, and never answer it yourself. Approval to integrate is not a choice of mode, and the mode used last time is not a default. `integrate-4-finish.ps1` makes `-Mode` mandatory so no run can skip the question.

| Mode | What it does | Choose it when |
| --- | --- | --- |
| `Commits` | Rebases and fast-forwards the base, keeping every branch commit | each commit is a meaningful step worth keeping in the base history |
| `Squash` | Collapses the branch into one commit, then fast-forwards the base | the branch is one logical change and the increments were the route, not the result |
| `Request` | Collapses the branch into one commit, pushes it, and opens a pull request | the change needs review or CI on the platform before it reaches the base |

`Commits` and `Squash` push the base and delete the feature branch. `Request` leaves the base untouched and the branch alive — the platform merges it. `gh` opens the request when it is installed; otherwise the script pushes and prints where to open it by hand.

The message for `Squash` and `Request` is validated by the `git-commit` format checker before anything is rewritten, so compose it there rather than inventing one.

## For AI agents — use the step scripts (non-interactive)

Run the progress cleanup first, then the step scripts from `agents/skills/git-integrate/scripts/`. Each script exits non-zero on failure.

| Step | Command |
| --- | --- |
| 0 — remove progress | `pwsh agents/skills/dev-workflow-clean-branch/scripts/remove-progress.ps1 [-BaseBranch <name>]` |
| 1 — check state | `pwsh integrate-1-check.ps1 [-BaseBranch <name>]` |
| 2 — squash commits (optional) | `pwsh integrate-2-squash.ps1 -Hash <hash> -Message '<msg>' [-BaseBranch <name>]` |
| 3 — rebase | `pwsh integrate-3-rebase.ps1 [-BaseBranch <name>]` |
| 4 — finish | `pwsh integrate-4-finish.ps1 -Mode <Commits\|Squash\|Request> [-Message '<msg>'] [-BaseBranch <name>]` |

**Procedure:**

1. Run **step 0** after `dev-workflow`'s `finish` operation and its deletion commit. It removes `.progress/` from every feature-branch commit and prunes progress-only commits.
2. Run **step 1**. Read the output: look at the recent log for WIP commits and the base-to-HEAD log for topic commits. It rejects any remaining progress history.
3. If WIP commits exist at the tip, run **step 2** with `<hash>` set to the commit just before the first WIP and a clean message.
4. Run **step 3** (fetch + rebase). Fix any conflicts; rebase pauses on them.
5. Run **step 1** again, then present the three modes to the user and wait for the answer.
6. Run **step 4** with the chosen `-Mode`, adding `-Message` for `Squash` and `Request`. It performs the collapse itself; step 2 is not run again.

## For humans — use the interactive script

Run `pwsh agents/skills/git-integrate/scripts/integrate.ps1` and follow its prompts. It asks the mode question and refuses to proceed until it is answered.
