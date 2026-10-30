---
name: git-commit
description: Compose and record a commit in the repository's unified Conventional Commits format — subject shape, bullet body, footers, and the pre-commit checks. Use whenever work is ready to commit, including the workflow COMMIT phase.
allowed-tools: PowerShell
metadata:
  dependencies: convention-commit-message git-commit-fix
---

# Commit

The message format is `convention-commit-message`; this skill records the commit and holds the checker that enforces that format. `git-commit-fix` rewrites existing history against the same checker.

## Procedure

1. Run `git log --oneline -6`. Squash tip-only WIP commits on the same concern into one clean commit before adding another.
2. Review the staged diff. If it carries more than one concern, split it. A formatting-only change and a mechanical rename are each a concern of their own.
3. Delegate the drafting to a subagent on a mid-tier model, as described below.
4. Check and record the returned draft in one call:

```powershell
pwsh <skill>/scripts/new-commit.ps1 `
    -Type fix -Scope ci `
    -ConventionCommitMessageSkill <convention-commit-message> `
    -Summary 'comma-separate cargo install --features on win-arm64' `
    'cargo took only env_logger from --features, making structopt a package' `
    'shell:true joins argv with unquoted spaces, splitting the value in two'
```

Body entries are the trailing arguments, one quoted string each, written without the `- ` marker. The script assembles the subject, prefixes the entries, appends `-Footer` lines after the single blank line, and commits only when `convention-commit-message`'s checker passes every rule; otherwise it prints the violations and commits nothing. `-Breaking` adds `!` and requires a `BREAKING CHANGE:` footer. `-DryRun` prints the message, `-Amend` rewrites the tip.

To validate a message that already exists, use `convention-commit-message`'s `check-message.ps1`. Committing never authorizes pushing.

## Drafting model

Writing a message against this format is a bounded task with a deterministic gate behind it, so it does not need the session's main model. Spawn a subagent and name a mid-tier model at the spawn — `sonnet` in Claude Code's subagent call, an explicit spawn model with `model_reasoning_effort: medium` in Codex's. Steps 1, 2, and 4 stay in the session.

The subagent cannot see the conversation, so pass it three things:

- the staged diff, or the instruction to run `git diff --staged` itself;
- one sentence of why the change was made, which is the only part of the body rules a diff cannot supply;
- the scope list from the host's root `AGENTS.md`, and the convention `convention-commit-message`.

It returns the type, scope, summary, and body entries as text and commits nothing. The session runs `new-commit.ps1`, so the write to history stays where the user is watching it. When the host tool cannot name a model for a subtask, draft in the session instead — the format and the checker are the same either way.
