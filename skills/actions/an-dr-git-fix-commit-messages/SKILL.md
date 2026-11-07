---
name: an-dr-git-fix-commit-messages
description: Rewrite existing commit messages on a branch so they match the commit message format, preserving every tree, author, and date. Use before a first release or before integration when history predates the format.
license: MIT
allowed-tools: PowerShell
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-convention-commit-message
---

# Fix commit history

Defers: format and validator to `an-dr-convention-commit-message`; read it first.

## Procedure

Run only before a first release or on an unpushed feature branch; rewriting published history forces every other clone to recover by hand.

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

Validates every replacement before writing any commit, so a violation aborts with history untouched. Records a backup ref under `refs/backup/an-dr-git-fix-commit-messages/`, preserves author and committer identity and dates, and aborts when the rewritten tip's tree differs from the old one.

4. Re-run step 1; it must report zero commits needing rewriting.

## Rules

- Messages only; never combine commits. When history needs regrouping, combine first, then rewrite the result's messages.
- The branch now diverges from its remote; `git push --force-with-lease` is the user's decision, never automatic.
