---
name: an-dr-convention-script
description: Rules for the PowerShell scripts a skill ships — PowerShell 7, non-interactive execution, tests under scripts/tests, a local test runner, and portable dependencies. Use when writing, changing, or reviewing any script under a skill.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.2.0"
  an-dr.type: convention
  an-dr.dependencies: an-dr-ai-send-message an-dr-convention-agent-skill-testing
---

# Convention: script

A skill adds a script only for repeated, mechanical work. The skill's `SKILL.md` says when the agent runs it; the script does the deterministic part.

- **Runtime:** PowerShell 7, starting with `#Requires -Version 7`, non-interactive, exiting non-zero on failure.
- **Tests:** follow `an-dr-convention-agent-skill-testing` for `scripts/tests/`, fixtures, the local `scripts/tests/run.ps1` entry point, and the boundary between free checks and agent evaluations.
- **After modifications:** run a skill's script tests after every change to that skill, its scripts, or its tests. Test the final edited scripts before delivery; a passing run from before the edit does not verify it. Report missing tests or failed assertions instead of claiming success. Script tests run without model calls or separate approval; paid behavioral evaluations require an explicit user request.
- **Output:** a script's result is printed for the user. Write it in `an-dr-ai-send-message`'s safe Markdown (pipe tables, short status lines, a report's path) with progress noise kept off stdout, so the agent can relay it as `an-dr-ai-send-message` requires without reshaping it. SKILL.md says what the output shows and that the agent relays it.
- **Own files:** reach the skill's own files through `$PSScriptRoot`. Never use an absolute path, a path through the repository's layout such as `skills/<name>`, or a submodule folder name.
- **Other skills:** call only a public script of another skill, through a folder the caller passes. Skills need not be installed side by side, so a script never guesses another skill's location, whether through `$PSScriptRoot/../..`, a registry, or a fixed path. It takes the folder as a mandatory parameter named after the skill, such as `-<Name>Skill`, and SKILL.md passes `<that-skill-name>` in the command. The script checks that the public script exists in that folder and throws naming the parameter when it does not. It never imports another skill's `.psm1` module. When a caller needs more than a public script offers, extend that script's parameters instead.
- **Vendored helpers:** a few generic functions that two skills need are copied into each one, and each copy is owned by its skill and marked as a copy. Sharing them is not worth the coupling.
- **Self-contained:** everything a script runs lives in its skill's folder. No folder at the repository root or elsewhere holds code that skills share, because it would tie every skill to this repository's layout and break a skill installed or published on its own.

## Check

```powershell
pwsh <skill>/scripts/check-scripts.ps1 [-Root <repository>]
```

It reports missing runtime declarations, nonportable dependencies, missing test runners, and script tests left in production folders, and exits non-zero on any. `scripts/tests/test-check-scripts.ps1` breaks a copy one way at a time and expects each break to be named. Run the tests with `pwsh <skill>/scripts/tests/run.ps1`.
