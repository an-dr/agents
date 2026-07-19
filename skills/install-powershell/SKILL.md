---
name: install-powershell
description: Install or verify PowerShell 7 when pwsh is unavailable or older than version 7 and repository skills require PowerShell. Use before running any .ps1 workflow or mechanical skill on a machine without a suitable pwsh executable.
---

# Install PowerShell

First run `pwsh --version`. Stop when it reports PowerShell 7 or newer.

If installation is required, identify the operating system and use its native
shell; this bootstrap skill cannot assume PowerShell already exists.

- Windows client: run
  `winget install --id Microsoft.PowerShell --source winget` from Command Prompt
  or Windows PowerShell.
- macOS: download the signed package for the machine architecture from
  `https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-macos`.
- Linux: follow Microsoft's distribution-specific package instructions at
  `https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell`.
  Do not guess a package command without identifying the distribution and
  version.

Ask before installing packages or elevating privileges. After installation,
open a new shell and verify both `pwsh --version` and
`pwsh -NoProfile -Command '$PSVersionTable.PSVersion'`.
