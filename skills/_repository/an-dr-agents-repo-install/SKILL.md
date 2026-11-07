---
name: an-dr-agents-repo-install
description: Install this agents clone globally for local AI tools (Claude Code, Codex, Copilot CLI, DeepSeek Harness, Gemini CLI, opencode) so every repository gets its policy and skills. Use when the user wants the workflow machine-wide, or to move, update, or verify a global install.
license: MIT
allowed-tools: PowerShell
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.2.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-skill-test
---

# Install agents globally

Defers: behavioral verification to `an-dr-ai-skill-test`.

## Install

```powershell
pwsh <skill>/scripts/install-agents.ps1
```

| Parameter            | Effect                                                                                                                    |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `-AgentsRoot <path>` | Clone to install from. Defaults to the clone holding this script.                                                         |
| `-Tools <ids>`       | Limit to `claude`, `codex`, `copilot`, `deepseek`, `gemini`, `opencode`. Default: every tool whose home directory exists. |
| `-SkipSkills`        | Write instruction blocks only, no junctions.                                                                              |
| `-Force`             | Replace a real directory occupying a skill link path.                                                                     |
| `-Uninstall`         | Remove the managed blocks and the junctions.                                                                              |

- Writes a managed block in each tool's user-level instruction file, pointing at this clone's `AGENTS.md`.
- Links each skill into each tool's global skills directory: a junction on Windows, a symbolic link on Linux/macOS; neither needs elevation or developer mode.
- Idempotent; edits only between its `agents-install` markers and replaces only links it recognises.
- A repository with this clone as its own `agents/` submodule wins over the global install, because its `AGENTS.md` is nearer the work.
- Re-run after adding a skill to the clone or moving the clone.
- The managed block makes the policy conditional: a flow starts only when the repository has a root `AGENTS.md`/`CLAUDE.md` referencing it, has `.progress/workflow.json`, or the user names a flow or skill; otherwise every scratch directory would get Direct work or gated-flow setup.

## Verify

```powershell
pwsh <skill>/scripts/verify-agents.ps1
```

Checks the clone, each tool's managed block and policy path, and every junction, including that `SKILL.md` is readable through the link. Prints a Markdown table; exits non-zero on any failure. Report the table to the user as-is.

## Handle what the scripts cannot

- Exit `2` (conflict): a real directory sits where a skill link belongs → read it, decide whether it is an unrelated same-name skill or a stale copy, then rename it or re-run with `-Force`. Never `-Force` blindly.
- `unsupported` skills row: the tool has no known user-level skills directory → check its current documentation; if one exists, add it to `Get-AgentsToolTarget` in `scripts/Install.Common.psm1`, not a hand-made link.
- Unknown tool → add it to the same function, with its instruction-file path and whether it supports `@` imports.
- `warn` on the git check: a dirty or non-git clone works but cannot update by `git pull` → tell the user which it is.
- The scripts prove files and links, not that a tool loaded them → report that coverage limit. `an-dr-ai-skill-test` runs cheap script tests always, behavioral cases only on explicit user request; installing links does not authorize new agent sessions.
- Anything else the script cannot fix → diagnose from its output; do not re-run with different flags until it passes.

## Move or remove the clone

Moving or deleting the clone leaves dangling junctions in every tool. Run `-Uninstall` first, or re-run the install from the new location; it repoints links and rewrites the blocks.
