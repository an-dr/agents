---
name: git-integrate
description: Integrate the current feature branch into the repository's default branch per repo rules — remove workflow progress from branch history, rebase and logically squash, fast-forward, push, and delete the feature branch.
allowed-tools: PowerShell
---

## For AI agents — use the step scripts (non-interactive)

Run the progress cleanup first, then the step scripts from `agents/skills/git-integrate/scripts/`. Each script exits non-zero on failure.

| Step | Command |
|------|---------|
| 0 — remove progress | `pwsh agents/skills/dev-workflow-clean-branch/scripts/remove-progress.ps1 [-BaseBranch <name>]` |
| 1 — check state | `pwsh integrate-1-check.ps1 [-BaseBranch <name>]` |
| 2 — squash commits (optional) | `pwsh integrate-2-squash.ps1 -Hash <hash> -Message '<msg>' [-BaseBranch <name>]` |
| 3 — rebase | `pwsh integrate-3-rebase.ps1 [-BaseBranch <name>]` |
| 4 — finish | `pwsh integrate-4-finish.ps1 [-BaseBranch <name>]` |

**Workflow:**

1. Run **step 0** after `dev-workflow`'s `finish` operation and its deletion commit. It removes `.progress/` from every feature-branch commit and prunes progress-only commits.
2. Run **step 1**. Read the output: look at the recent log for WIP commits and the base-to-HEAD log for topic commits. It rejects any remaining progress history.
3. If WIP commits exist at the tip, run **step 2** with `<hash>` set to the commit just before the first WIP and a clean message.
4. Run **step 3** (fetch + rebase). Fix any conflicts; rebase pauses on them.
5. Run **step 1** again. If multiple topic commits should be one, run **step 2** with `-Hash <base-branch>`.
6. Run **step 4** to fast-forward and push the base, then delete the feature branch locally and remotely.

---

## For humans — use the interactive script

Run `pwsh agents/skills/git-integrate/scripts/integrate.ps1` and follow its prompts.
