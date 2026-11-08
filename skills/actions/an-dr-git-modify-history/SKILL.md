---
name: an-dr-git-modify-history
description: Change a repository's local history — record commits in the Conventional Commits format, regroup unpushed commits into coherent ones, and rewrite non-conforming messages. Use whenever work is ready to commit, including the workflow COMMIT phase, and before any push or integration of unpushed commits.
license: MIT
allowed-tools: PowerShell
metadata:
  author: Andrei Gramakov (an-dr)
  version: "2.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-convention-commit-message
---

# Modify history

Defers: the message format and its checker to `an-dr-convention-commit-message`.

## When to use which section

| Situation                                              | Section                               |
| ------------------------------------------------------ | ------------------------------------- |
| Work is ready to commit                                | Regroup unpushed commits, then Commit |
| About to push, or to hand a branch to integration      | Regroup unpushed commits              |
| Commits on an unpushed branch break the message format | Rewrite messages                      |
| One message to check                                   | Check an existing message             |

## Regroup unpushed commits

Unpushed commits are `git log --oneline @{u}..HEAD`; without an upstream, the merge base with the default branch to `HEAD`. On the agent's own work branch (`vibe/`, `spec/`, `supervised/`), which is pushed automatically, every commit after the merge base with the base branch counts as unpushed, and a regroup is pushed with `--force-with-lease`; while its pull or merge request is under review, add commits instead and regroup only after the `integrate` approval. Evaluate them every time before committing and before pushing, and regroup with `git reset --soft`, `git commit --fixup` plus `git rebase --autosquash`, or a non-interactive rebase:

- Fold a fix, a follow-up, or a "WIP" into the commit it corrects.
- Drop add-then-remove pairs: a change and its revert, or a line added and later deleted, leave no trace in history.
- Merge small commits in the same area into one commit that names each change as a body entry.
- Keep unrelated concerns apart; a formatting-only change and a mechanical rename stay their own commits.
- A commit is too small when it cannot be understood or reverted on its own.
- Never rewrite a commit pushed to any other branch. Each regrouped commit's message goes through Commit's checker.

## Commit

1. Review the staged diff; split it if it carries more than one concern.
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
- On a work branch, push after every commit (`git push -u origin HEAD` the first time); never push the base branch from here.
- `-Breaking` adds `!` and requires a `BREAKING CHANGE:` footer; `-DryRun` prints the message; `-Amend` rewrites the tip.

## Rewrite messages

Run only before a first release or on an unpushed branch; rewriting published history forces every other clone to recover by hand. Regroup first, then rewrite the result's messages.

1. Find what breaks the format; changes nothing:

```powershell
pwsh <skill>/scripts/check-history.ps1 -CommitMessageSkill <an-dr-convention-commit-message> [-Range <rev>] [-FromRoot] [-FailingOnly]
```

Default range: merge base with the default branch to `HEAD`; refuses to guess a range while the default branch is checked out.

2. For each failing commit, read what it did (`git show --stat <sha>`, the diff when the subject is unclear) and write the replacement to `<directory>/<sha>.txt`. Short hashes work; commits without a file keep their message; the directory is outside the repository, since rewriting requires a clean working tree.
3. Apply the replacements:

```powershell
pwsh <skill>/scripts/rewrite-messages.ps1 -MessageDirectory <directory> -CommitMessageSkill <an-dr-convention-commit-message> [-Range <rev>] [-FromRoot]
```

Validates every replacement before writing any commit, so a violation aborts with history untouched. Records a backup ref under `refs/backup/an-dr-git-modify-history/`, preserves author and committer identity and dates, and aborts when the rewritten tip's tree differs from the old one.

4. Re-run step 1; it must report zero commits needing rewriting.

## Check an existing message

```powershell
pwsh <an-dr-convention-commit-message>/scripts/check-message.ps1 -Path <file>
pwsh <an-dr-convention-commit-message>/scripts/check-message.ps1 -Commit HEAD
```

Exits non-zero on a violation and prints length warnings; relay both to the user.

## Rules

- Committing never authorizes pushing.
- After a rewrite the branch diverges from its remote; `git push --force-with-lease` is the user's decision, never automatic.
