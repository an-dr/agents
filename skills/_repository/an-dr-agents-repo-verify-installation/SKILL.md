---
name: an-dr-agents-repo-verify-installation
description: Diagnose why an AI tool ignores this workflow's policy by checking the machine install, this repository's opt-in wiring, and whether the session loaded the policy, then recommend the fix. Use when a tool ignores the policy, bypasses the workflow controller, or obeys while another tool does not.
license: MIT
allowed-tools: PowerShell Read Grep Glob
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.2.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-agents-repo-install an-dr-ai-skill-implement-test an-dr-ai-skill-test an-dr-convention-commit-message
---

# Agents health check

Defers: install fixes to `an-dr-agents-repo-install`, regression coverage to `an-dr-ai-skill-implement-test` and `an-dr-ai-skill-test`.

Diagnose layers in order; the first broken layer explains the symptom, and fixing a later one changes nothing.

| Layer      | Question                                                     | Owner                                                                |
| ---------- | ------------------------------------------------------------ | -------------------------------------------------------------------- |
| Machine    | Is the policy installed for this tool?                       | `check-agents-health.ps1`, delegating to `an-dr-agents-repo-install` |
| Repository | Does this repository opt in, and does its reference resolve? | `check-agents-health.ps1`                                            |
| Pickup     | Did the bot load and act on what is wired?                   | this skill; no script can see it                                     |

## Run

```powershell
pwsh <skill>/scripts/check-agents-health.ps1
```

| Parameter                | Effect                                                                                     |
| ------------------------ | ------------------------------------------------------------------------------------------ |
| `-RepositoryPath <path>` | Repository to diagnose; default current directory; a subdirectory resolves to its git root |
| `-AgentsRoot <path>`     | Clone the global install should point at; passed to the install verifier                   |
| `-Tools <ids>`           | Limit the install layer to `claude`, `codex`, `copilot`, `deepseek`, `gemini`, `opencode`  |
| `-SkipInstallCheck`      | Repository layer only, when the machine install is known good                              |

- Prints one Markdown table for the machine and repository layers; exits non-zero on any failure.
- Relay the table as-is, then check pickup; a `pass` verdict means the answer lies there.

## Pickup

Check from inside the session under investigation, not by reading files.

1. Policy in context: ask the tool to state the four requirement facts, the three commands, or the flow table without reading a file. Reaching for `AGENTS.md` first or a generic paraphrase → not loaded.
2. Opt-in guard: for file changes in an opted-in host, the agent resumes existing workflow state or uses the user's selected flow; only with neither does it ask the three-way selection; a preselected flow needs no second question. Scratch directory without opt-in → it proposes no flow. Read-only tasks and edits to this process repository follow the `AGENTS.md` exceptions.
3. Skills visible: ask the tool to list its invocable skills. Resolving junctions still fail to register when the tool caches its skill list at startup or has no user-level skills directory; the install verifier reports the latter as `unsupported`.
4. Real task followed the flow: establish the selected flow and phase when the behaviour occurred first. Vibe: a `vibe/` branch unless the user asked for the current one, no controller state. Spec-driven and Supervised: controller state while active and a work branch before docs or implementation changes, unless Spec-driven runs on the base at the user's request. Completed gated work has no state. Check approvals, review, tests, and delivery against `AGENTS.md`; report only a concrete violation of that flow.

## Recommend

- Name the layer, the cause, and one command or edit, for the first broken layer only.
- For the finding-to-fix table, read [references/fixes.md](references/fixes.md).
- Regression coverage for a concrete failure → `an-dr-ai-skill-implement-test` (script tests, behaviour cases). After a skill change → `an-dr-ai-skill-test` script verification; agent evaluations only on explicit user request.
- Diagnosis never starts behaviour evaluations or paid agent sessions.

## Rules

- Diagnose before recommending; re-running the installer is wrong whenever the broken layer is repository or pickup.
- Never conclude health from the script alone; it proves wiring, not behaviour.
- Report a layer broken only with its evidence: a failing row, a missing file, or what the agent did.
- Fixing the repository layer edits the host repository, under that repository's workflow rules.
