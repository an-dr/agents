---
name: agents-install
description: Install this agents clone globally for local AI tools (Claude Code, Codex, Gemini CLI, opencode) so every repository can use its policy and skills without a submodule. Use when the user wants the workflow available by default machine-wide, wants to move or update an existing global install, or wants to verify one.
allowed-tools: PowerShell
---

# Install agents globally

Wires one clone of this repository into each tool's **user-level** configuration instead of embedding it per repository:

1. a managed block in each tool's global instruction file, pointing at this clone's `AGENTS.md`;
2. one directory junction per skill in each tool's global skills directory.

Use `agents-integration` instead when a specific repository should carry the workflow in its own history for other people. The two coexist: a repository submodule wins because its `AGENTS.md` is nearer the work.

## Install

From anywhere:

```powershell
pwsh <clone>/skills/agents-install/scripts/install-agents.ps1
```

| Parameter | Effect |
| --- | --- |
| `-AgentsRoot <path>` | Clone to install from. Defaults to the clone holding this script. |
| `-Tools <ids>` | Limit to `claude`, `codex`, `gemini`, `opencode`. Default: every tool whose home directory exists. |
| `-SkipSkills` | Write instruction blocks only, no junctions. |
| `-Force` | Replace a real directory occupying a skill link path. |
| `-Uninstall` | Remove the managed blocks and the junctions. |

The script is idempotent. It edits only between its `agents-install` markers, never other content in those files, and only ever replaces links it recognises. Junctions need no administrator rights or developer mode.

Re-run it after adding a skill to the clone, or after moving the clone.

## Opt-in guard

A global install has no submodule to signal intent, so the block it writes makes the policy conditional: a flow starts only when the repository has a root `AGENTS.md`/`CLAUDE.md` referencing it, has `.progress/workflow.json`, or the user names a flow or skill. Without that guard every scratch directory would get branch and increment proposals.

## Verify

```powershell
pwsh <clone>/skills/agents-install/scripts/verify-agents.ps1
```

Checks the clone, each tool's managed block and policy path, and every junction — including that `SKILL.md` is readable *through* the link. Prints a Markdown table and exits non-zero on any failure. Report that table to the user as-is.

## Where the agent takes over

The scripts do only what is mechanical and safe. Handle these yourself:

- **Conflict exit (`2`)** — a real directory sits where a skill link belongs. Read it, decide whether it is an unrelated skill of the same name or a stale copy, and either rename it or re-run with `-Force`. Never `-Force` blindly.
- **`unsupported` skills row** — that tool has no known user-level skills directory. Check its current documentation; if one now exists, add it to `Get-AgentsToolTarget` in `scripts/Install.Common.psm1` rather than linking by hand.
- **A tool the script does not know** — add it to the same function, with the correct instruction-file path and whether it supports `@` imports.
- **`warn` on the git check** — a dirty or non-git clone still works but cannot be updated by `git pull`. Tell the user which it is.
- **Semantic verification** — the script proves the files and links are right, not that a tool loaded them. Confirm by starting a session in an unrelated repository and checking the policy is visible but no flow is proposed.
- **Anything the script reports that it cannot fix** — diagnose from its output rather than re-running it with different flags until it passes.

## Moving or removing the clone

Deleting or moving the clone leaves dangling junctions in every tool. Run `-Uninstall` first, or re-run the install from the new location — it repoints existing links and rewrites the blocks.
