---
name: merge
description: Merge the current feature branch into the repository's default branch per repo rules — no merge commits, rebase and logical squashing, fast-forward, push, and delete the feature branch.
allowed-tools: PowerShell
---

## For AI agents — use the step scripts (non-interactive)

Run steps in order from `agents/skills/merge/scripts/`. Each script exits non-zero on failure.

| Step | Command |
|------|---------|
| 1 — check state | `pwsh merge-1-check.ps1 [-BaseBranch <name>]` |
| 2 — squash commits (optional) | `pwsh merge-2-squash.ps1 -Hash <hash> -Message '<msg>' [-BaseBranch <name>]` |
| 3 — rebase | `pwsh merge-3-rebase.ps1 [-BaseBranch <name>]` |
| 4 — finish | `pwsh merge-4-finish.ps1 [-BaseBranch <name>]` |

**Workflow:**

1. Run **step 1**. Read the output: look at the recent log for WIP commits and the base-to-HEAD log for topic commits. Pass `-BaseBranch` when `origin/HEAD` and common branch names cannot identify the default branch.
2. If WIP commits exist at the tip (same concern as the current work), run **step 2** with `<hash>` = the commit just before the first WIP, and a clean message.
3. Run **step 3** (fetch + rebase). Fix any conflicts; rebase will pause if there are any.
4. Run **step 1** again. If multiple topic commits should be one, run **step 2** with `-Hash <base-branch>`.
5. Run **step 4** to fast-forward and push the base, then delete the feature branch locally and remotely.

---

## For humans — use the interactive script

Run `pwsh agents/skills/merge/scripts/merge.ps1` and follow its prompts.
