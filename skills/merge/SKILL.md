---
name: merge
description: Merge the current feature branch into main per repo rules — no merge commits, rebase+squash, fast-forward, delete branch.
allowed-tools: Bash, PowerShell
---

Run the script for the current platform:

- **Linux / macOS:** `bash agents/skills/merge/scripts/merge.sh`
- **Windows:** `pwsh agents/skills/merge/scripts/merge.ps1`

The script is interactive — it will prompt before each destructive step.
