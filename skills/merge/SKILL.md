---
name: merge
description: Merge the current feature branch into main per repo rules — no merge commits, rebase+squash, fast-forward, delete branch.
allowed-tools: Bash, PowerShell
---

## For AI agents — use the step scripts (non-interactive)

Run steps in order from `agents/skills/merge/scripts/`. Each script exits non-zero on failure.

| Step | Linux / macOS | Windows |
|------|---------------|---------|
| 1 — check state | `bash merge-1-check.sh` | `pwsh merge-1-check.ps1` |
| 2 — squash commits (optional) | `bash merge-2-squash.sh <hash> '<msg>'` | `pwsh merge-2-squash.ps1 -Hash <hash> -Message '<msg>'` |
| 3 — rebase onto main | `bash merge-3-rebase.sh` | `pwsh merge-3-rebase.ps1` |
| 4 — finish | `bash merge-4-finish.sh` | `pwsh merge-4-finish.ps1` |

**Workflow:**

1. Run **step 1**. Read the output: look at `git log --oneline -6` for WIP commits at the tip, and `git log --oneline main..HEAD` for topic commits.
2. If WIP commits exist at the tip (same concern as the current work), run **step 2** with `<hash>` = the commit just before the first WIP, and a clean message.
3. Run **step 3** (fetch + rebase). Fix any conflicts; rebase will pause if there are any.
4. Run **step 1** again to review commits since main. If multiple topic commits should be one, run **step 2** with `-Hash main`.
5. Run **step 4** to fast-forward main, push, and delete the feature branch.

---

## For humans — use the interactive script (prompts at each step)

- **Linux / macOS:** `bash agents/skills/merge/scripts/merge.sh`
- **Windows:** `pwsh agents/skills/merge/scripts/merge.ps1`
