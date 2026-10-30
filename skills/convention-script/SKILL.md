---
name: convention-script
description: Rules for the PowerShell scripts a skill ships — PowerShell 7, non-interactive, non-zero exit on failure, a test beside each branching script, output written for the user, and other skills reached only through a passed folder. Use when writing, changing, or reviewing any script under a skill.
metadata:
  dependencies: agents-ui
---

# Convention: script

A skill adds a script only for repeated, mechanical work. The skill's `SKILL.md` says when the agent runs it; the script does the deterministic part.

- **Runtime:** PowerShell 7, starting with `#Requires -Version 7`, non-interactive, exiting non-zero on failure.
- **Tests:** each script with branching logic gets a `test-<script>.ps1` beside it that writes its fixtures under `.artifacts/` and prints one pass line. `tests/run-all.ps1` finds and runs every one.
- **Output:** a script's result is printed for the user. Write it in `agents-ui`'s safe Markdown (pipe tables, short status lines, a report's path) with progress noise kept off stdout, so the agent can relay it as `agents-ui` requires without reshaping it. SKILL.md says what the output shows and that the agent relays it.
- **Own files:** reach the skill's own files through `$PSScriptRoot`. Never use an absolute path, a path through the repository's layout such as `skills/<name>`, or a submodule folder name.
- **Other skills:** call only a public script of another skill, through a folder the caller passes. Skills need not be installed side by side, so a script never guesses another skill's location, whether through `$PSScriptRoot/../..`, a registry, or a fixed path. It takes the folder as a mandatory parameter named after the skill, such as `-<Name>Skill`, and SKILL.md passes `<that-skill-name>` in the command. The script checks that the public script exists in that folder and throws naming the parameter when it does not. It never imports another skill's `.psm1` module. When a caller needs more than a public script offers, extend that script's parameters instead.
- **Vendored helpers:** a few generic functions that two skills need are copied into each one, and each copy is owned by its skill and marked as a copy. Sharing them is not worth the coupling.
- **Self-contained:** everything a script runs lives in its skill's folder. No folder at the repository root or elsewhere holds code that skills share, because it would tie every skill to this repository's layout and break a skill installed or published on its own.

## Check

```powershell
pwsh <skill>/scripts/check-scripts.ps1 [-Root <repository>]
```

It reports every script that lacks `#Requires -Version 7` and every script that guesses another skill's location, and exits non-zero on any. `test-check-scripts.ps1` in the same folder breaks a copy one way at a time and expects each break to be named.
