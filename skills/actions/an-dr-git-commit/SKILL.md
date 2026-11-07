---
name: an-dr-git-commit
description: Compose and record a commit in the repository's Conventional Commits format, with the pre-commit checks. Use whenever work is ready to commit, including the workflow COMMIT phase.
license: MIT
allowed-tools: PowerShell
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-convention-commit-message
---

# Commit

Defers: the message format and its checker to `an-dr-convention-commit-message`.

## Procedure

1. Run `git log --oneline -6`; squash tip-only WIP commits on the same concern into one before adding another.
1. Review the staged diff; split it if it carries more than one concern. A formatting-only change and a mechanical rename are each their own concern.
1. Delegate drafting to a subagent on a mid-tier model. For the spawn and its inputs, read [references/drafting.md](references/drafting.md).
1. Check and record the returned draft in one call:

```powershell
pwsh <skill>/scripts/new-commit.ps1 `
    -Type fix -Scope ci `
    -CommitMessageSkill <an-dr-convention-commit-message> `
    -Summary 'comma-separate cargo install --features on win-arm64' `
    'cargo took only env_logger from --features, making structopt a package' `
    'shell:true joins argv with unquoted spaces, splitting the value in two'
```

- Trailing arguments are body entries, one quoted string each, without the `- ` marker.
- The script assembles the subject, prefixes entries, appends `-Footer` lines after the single blank line, and commits only when the checker passes; otherwise it prints violations and commits nothing.
- `-Breaking` adds `!` and requires a `BREAKING CHANGE:` footer; `-DryRun` prints the message; `-Amend` rewrites the tip.

## Check an existing message

```powershell
pwsh <an-dr-convention-commit-message>/scripts/check-message.ps1 -Path <file>
pwsh <an-dr-convention-commit-message>/scripts/check-message.ps1 -Commit HEAD
```

Exits non-zero on a violation and prints length warnings; relay both to the user.

## Rules

- Committing never authorizes pushing.
