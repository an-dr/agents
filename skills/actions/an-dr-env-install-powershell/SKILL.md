---
name: an-dr-env-install-powershell
description: Install or verify PowerShell 7 when pwsh is missing or older than version 7. Use before running any .ps1 workflow or mechanical skill on a machine without a suitable pwsh.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message
---

# Install PowerShell

1. Run `pwsh --version`. Stop when it reports 7 or newer.
2. Identify the operating system; use its native shell, since PowerShell may not exist.
3. Ask before installing packages or elevating, as an `an-dr-ai-send-message` confirmation naming the exact command.
4. Install:
   - Windows client: `winget install --id Microsoft.PowerShell --source winget` from Command Prompt or Windows PowerShell.
   - macOS: the signed package for the machine architecture from `https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-macos`.
   - Linux: Microsoft's distribution-specific instructions at `https://learn.microsoft.com/en-us/powershell/scripting/install/an-dr-env-install-powershell`. Never guess a package command without the distribution and version.
5. Open a new shell; verify `pwsh --version` and `pwsh -NoProfile -Command '$PSVersionTable.PSVersion'`.
