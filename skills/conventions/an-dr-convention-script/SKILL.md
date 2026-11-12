---
name: an-dr-convention-script
description: Rules for the PowerShell scripts a skill ships — PowerShell 7, non-interactive execution, tests under scripts/tests, a local test runner, and portable dependencies. Use when writing, changing, or reviewing any script under a skill.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.5.0"
  an-dr.type: convention
  an-dr.dependencies: an-dr-ai-use-user-interface an-dr-convention-agent-skill-testing
---

# Convention: script

Defers: `scripts/tests/`, fixtures, the `scripts/tests/run.ps1` entry point, and free checks versus agent evaluations to `an-dr-convention-agent-skill-testing`; output form to `an-dr-ai-use-user-interface`.

## Rules

- A script exists only for repeated, mechanical work; `SKILL.md` says when it runs.
- Exception: `an-dr-ai-use-user-interface/scripts/ai-ui.py` is Python 3, standard library only, by intent: a local HTTP server is simpler and safer there. It keeps the other runtime rules (non-interactive, non-zero exit on failure, own files only) and states the exception in its header; it ships without script tests by the user's decision. Another exception needs the same explicit, recorded reason.
- Runtime: PowerShell 7, first line `#Requires -Version 7`, non-interactive, non-zero exit on failure.
- A skill's script tests run after every change to the skill, its scripts, or its tests, against the final edited scripts; a pre-edit pass verifies nothing.
- Missing tests or failed assertions are reported, never claimed as success.
- Script tests need no model calls or separate approval; paid behavioral evaluations need an explicit user request.
- Output is printed for the user in `an-dr-ai-use-user-interface`'s safe Markdown (pipe tables, short status lines, a report path), progress noise off stdout, so it is relayed without reshaping; `SKILL.md` says what it shows and that it is relayed.
- User-facing stdout sits between `<!-- user-output: verbatim -->` or `<!-- user-output: summarize -->` and `<!-- /user-output -->`, each marker on its own line, emitted with plain `Write-Output`, no shared helper.
- `verbatim`: read exactly as printed, such as a status table. `summarize`: condensed by the agent, such as findings or a long list. Outside the markers: detail the agent may omit.
- Own files are reached through `$PSScriptRoot`; never an absolute path, a repository-layout path such as `skills/<name>`, or a submodule folder name.
- Another skill is reached only through its public script, in a folder passed as a mandatory parameter named after the skill (`-<Name>Skill`); `SKILL.md` passes `<that-skill-name>`. Skills need not be installed side by side, so no `$PSScriptRoot/../..`, registry, or fixed path.
- The script checks the public script exists in that folder and throws naming the parameter when not.
- Another skill's `.psm1` is never imported; a caller needing more extends that public script's parameters.
- A few generic functions two skills need are copied into each, owned by that skill and marked as a copy; sharing is not worth the coupling.
- Everything a script runs lives in its skill's folder; no shared code folder at the root or elsewhere, which would break a skill installed or published alone.

## Check

`scripts/check-scripts.ps1` reports missing runtime declarations, nonportable dependencies, missing test runners, and script tests left in production folders, and exits non-zero on any. Its regression test breaks a copy one way at a time and expects each break named.
