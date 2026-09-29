---
name: agents-health-check
description: Diagnose why an AI tool is not following this workflow — the policy is installed but the agent ignores it, gated work bypasses dev-workflow, or one tool obeys while another does not. Checks the machine install, this repository's opt-in wiring, and whether the bot actually loaded the policy, then recommends the fix.
allowed-tools: PowerShell, Read, Grep, Glob
---

# Agents health check

Answers one question: **why is the agent not behaving as the policy says it should?**

Installation is only the first of three layers, and a passing install proves the least interesting one. Diagnose in order — the first broken layer explains the symptom, and fixing a later layer while an earlier one is broken changes nothing.

| Layer | Question | Owner |
| --- | --- | --- |
| Machine | Is the policy installed for this tool at all? | `check-agents-health.ps1`, delegating to `agents-install` |
| Repository | Does *this* repository opt in, and does its reference resolve? | `check-agents-health.ps1` |
| Pickup | Did the bot actually load and act on what is wired? | this skill, below — no script can see it |

## Run

```powershell
pwsh agents/skills/agents-health-check/scripts/check-agents-health.ps1
```

| Parameter | Effect |
| --- | --- |
| `-RepositoryPath <path>` | Repository to diagnose. Defaults to the current directory; a subdirectory resolves to its git root. |
| `-AgentsRoot <path>` | Clone the global install should point at. Passed through to the install verifier. |
| `-Tools <ids>` | Limit the install layer to `claude`, `codex`, `gemini`, `opencode`. |
| `-SkipInstallCheck` | Repository layer only, when the machine install is known good. |

The script prints one Markdown table covering the machine and repository layers and exits non-zero on any failure. Report that table to the user as-is, then continue with the pickup layer yourself — a `pass` verdict is precisely the case where the answer lies there.

## Pickup

Only the running session can observe this layer, so check it from inside the session under investigation rather than by reading files.

1. **Is the policy in context?** Ask the tool to state the four requirement facts, the three commands, or the flow table without reading a file. It has the policy if it answers from context; it does not if it reaches for `AGENTS.md` first or paraphrases something generic.
2. **Does the opt-in guard fire?** A global install is deliberately silent unless the repository opts in. For file changes in an opted-in host repository, the agent resumes existing workflow state or uses the user's selected flow. Only when neither exists does it ask for the four-way selection. A preselected flow needs no second question. In a scratch directory with no opt-in, it must not propose a flow. Read-only tasks and edits to this process repository follow the exceptions in `AGENTS.md`.
3. **Are the skills visible?** Ask the tool to list the skills it can invoke. Junctions that resolve on disk still fail to register when the tool caches its skill list at startup, or when the tool has no user-level skills directory at all — the install verifier reports that as `unsupported`.
4. **Did a real task follow the flow?** Establish the selected flow and the phase when the behavior occurred before identifying a skipped rule. Direct uses the current branch without `.progress/`; Quick uses the current branch with controller state while active; Detailed and Detailed Auto require controller state while active and a feature branch before documentation or implementation changes. Completed gated work removes its state, so its absence after completion is expected. Check the applicable approvals, review, tests, and delivery against `AGENTS.md`; report only a concrete violation of that flow.

## Recommend

Name the layer, the cause, and one command or edit. Do not propose a fix for a layer that is not the first broken one.

| Finding | Fix |
| --- | --- |
| Install rows fail | Re-run `agents-install`'s `install-agents.ps1`; its SKILL.md owns conflicts, `unsupported` rows, and unknown tools. |
| No root `AGENTS.md`/`CLAUDE.md`, or it does not reference the policy | Add a root instruction file referencing `agents/AGENTS.md` — but only if this repository should be governed. The `verdict` row reports this as `info`, not a failure, because silence in an un-wired repository is the guard working. |
| `AGENTS.md` without `CLAUDE.md`, or the reverse | Add the missing one; Claude Code reads `CLAUDE.md`, Codex and opencode read `AGENTS.md`. A repository wired for one tool is invisible to the other. |
| `agents/` present but empty | `git submodule update --init --recursive`. |
| No `## Commit scopes` section | Add one to the root `AGENTS.md`; `git-commit`'s checker rejects every scoped subject without it. |
| Everything wired, policy not in context | A tool-side loading problem: instruction file too large, an `@` import the tool does not expand, a cached session. Restart the session, then reduce what the block asks the tool to load. |
| Everything wired and loaded, but the agent still skipped the flow | The instructions are ambiguous or too weak for that tool. This is a process defect, not an installation one — hand it to `agents-retro`. |

The last row is the boundary of this skill. A rule that one tool follows and another ignores is evidence about the wording, and belongs in a retro proposal against `AGENTS.md` or a skill; `agents-retro` requires evidence from real work, so carry the concrete task that went wrong into it rather than the observation alone.

## Rules

- Diagnose before recommending. Re-running the installer is not a diagnosis, and it is the wrong answer whenever the broken layer is the repository or pickup.
- Never conclude from the script alone that the agent is healthy. It proves the wiring, not the behaviour; the pickup layer needs the session's own answers.
- Report a layer as broken only with the evidence that showed it — a failing row, a missing file, or what the agent actually did.
- Fixing the repository layer edits the host repository, not this one, and follows that repository's own workflow rules.
