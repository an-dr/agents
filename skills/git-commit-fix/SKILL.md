---
name: git-commit-fix
description: Rewrite existing commit messages on a branch so they match the git-commit format, preserving every tree, author, and date. Use before a first release or before integration when history predates the format.
allowed-tools: PowerShell
---

# Fix commit history

Rewrites messages only. The `git-commit` skill defines the format and holds the validator both skills call, so read it first and never restate its rules here.

Rewriting published history forces every other clone to recover by hand. Run this only where that is agreed: before a first release, or on an unpushed feature branch.

## Procedure

1. Find what breaks the format. Changes nothing:

```powershell
pwsh agents/skills/git-commit-fix/scripts/check-history.ps1 [-Range <rev>] [-FromRoot] [-FailingOnly]
```

Without arguments it checks the merge base with the default branch to `HEAD`, and refuses to guess a range while the default branch is checked out.

2. For each failing commit, read what it actually did — `git show --stat <sha>` first, the diff when the subject is unclear — and write the replacement to `<directory>/<sha>.txt`. Short hashes are fine. Commits without a file keep their message. Put the directory outside the repository; rewriting requires a clean working tree.

3. Apply the replacements:

```powershell
pwsh agents/skills/git-commit-fix/scripts/rewrite-messages.ps1 -MessageDirectory <directory> [-Range <rev>] [-FromRoot]
```

Every replacement is validated before any commit is written, so a rule violation aborts with history untouched. The script records a backup ref under `refs/backup/git-commit-fix/`, preserves author and committer identity and dates, and verifies that the rewritten tip has an identical tree to the old one — a content change aborts the run.

4. Re-run step 1. It must report zero commits needing rewriting.

## Squashing

This skill fixes messages; it never combines commits. When history also needs regrouping, squash first with `git-integrate`'s step 2 script, then rewrite the messages of the result.

## Afterwards

The branch has diverged from its remote. Pushing needs `git push --force-with-lease`, which is a user decision and never automatic.
