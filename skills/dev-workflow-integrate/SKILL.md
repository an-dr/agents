---
name: dev-workflow-integrate
description: Integrate an approved feature branch into the default branch in one of five modes — keep the commits, regroup them into a few logical commits, squash into one commit, open a request, or land a regrouped request with rebase and merge. Use after the integration gate; it removes workflow progress, rebases, applies the chosen mode, and cleans up the branch.
allowed-tools: PowerShell
metadata:
  dependencies: agents-ui convention-commit-message dev-workflow-clean-branch git-commit
---

# Integrate

Integration always rebases first, so the default branch never gains a merge commit from this skill. What happens after the rebase is the user's choice between five modes.

## The mode question

Ask it every time, before any mode-specific step, and never answer it yourself. Approval to integrate is not a choice of mode, and the mode used last time is not a default. `integrate-4-finish.ps1` makes `-Mode` mandatory so no run can skip the question.

| Mode | What it does | Choose it when |
| --- | --- | --- |
| `Commits` | Rebases and fast-forwards the base, keeping every branch commit | each commit is a meaningful step worth keeping in the base history |
| `Regroup` | Rebuilds the branch as the few logical commits the user asks for, then fast-forwards the base like `Commits` | the increments were too many to keep, but the change has parts worth separating |
| `Squash` | Collapses the branch into one commit, then fast-forwards the base | the branch is one logical change and the increments were the route, not the result |
| `Request` | Collapses the branch into one commit, pushes it, and opens a pull request | the change needs review or CI on the platform before it reaches the base |
| `RebaseMerge` | Regroups the branch into at most five logical commits, pushes them, opens a pull request, fixes CI on it, and lands it with the platform's rebase and merge | the change needs CI on the platform, and its parts belong in the base history as separate commits |

`Commits`, `Regroup`, and `Squash` push the base and delete the feature branch. `Request` leaves the base untouched and the branch alive — the platform merges it. `RebaseMerge` lands through the platform too, but the agent drives it there, as described below. `gh` opens the request when it is installed; otherwise the script pushes and prints where to open it by hand.

The message for `Squash` and `Request` is validated by `convention-commit-message`'s checker before anything is rewritten, so compose it with `git-commit` rather than inventing one.

## For AI agents — use the step scripts (non-interactive)

Run the progress cleanup first, then the step scripts from `<skill>/scripts/`. Each script exits non-zero on failure. `<convention-commit-message>` and `<dev-workflow-clean-branch>` are those skills' folders, wherever the agent loaded them from; the scripts take them as parameters instead of guessing where they are installed.

| Step | Command |
| --- | --- |
| 0 — remove progress | `pwsh <dev-workflow-clean-branch>/scripts/remove-progress.ps1 [-BaseBranch <name>]` |
| 1 — check state | `pwsh integrate-1-check.ps1 [-BaseBranch <name>]` |
| 2 — squash commits (optional) | `pwsh integrate-2-squash.ps1 -Hash <hash> -Message '<msg>' -ConventionCommitMessageSkill <convention-commit-message> [-BaseBranch <name>]` |
| 2 — regroup commits (`Regroup` only) | `pwsh integrate-2-regroup.ps1 -Plan <plan.json> -ConventionCommitMessageSkill <convention-commit-message> [-BaseBranch <name>]` |
| 3 — rebase | `pwsh integrate-3-rebase.ps1 [-BaseBranch <name>]` |
| 4 — finish | `pwsh integrate-4-finish.ps1 -Mode <Commits\|Squash\|Request\|RebaseMerge> [-Message '<msg>' -ConventionCommitMessageSkill <convention-commit-message>] [-BaseBranch <name>]` |
| 5 — rebase-merge (`RebaseMerge` only) | `pwsh integrate-5-rebase-merge.ps1 -TestedCommit <sha> [-BaseBranch <name>]` |

**Procedure:**

1. Run **step 0** after the workflow's `finish` operation and its deletion commit. It removes `.progress/` from every feature-branch commit and prunes progress-only commits.
2. Run **step 1**. Read the output: look at the recent log for WIP commits and the base-to-HEAD log for topic commits. It rejects any remaining progress history.
3. If WIP commits exist at the tip, run **step 2** with `<hash>` set to the commit just before the first WIP and a clean message.
4. Run **step 3** (fetch + rebase). Fix any conflicts; rebase pauses on them.
5. Run **step 1** again, then ask for the mode as one `agents-ui` question with the five modes as its options, no recommendation, and wait for the answer. When the host's question UI holds fewer than five options, ask first whether to land locally (`Commits`, `Regroup`, `Squash`) or through a pull request (`Request`, `RebaseMerge`), then which mode within that group.
6. Run **step 4** with the chosen `-Mode`, adding `-Message` for `Squash` and `Request`. It performs the collapse itself; step 2 is not run again. For `Regroup`, first rebuild the branch as described below, then run step 4 with `-Mode Commits`. For `RebaseMerge`, continue as described in its section.

## Regroup

Ask how many commits the user wants when the answer does not say. Then:

1. **Plan the commits** in dependency order, so each builds on the ones before it: typically the contract or library a change rests on, then its users, then tools, then documentation. Write the plan as JSON, `{ "commits": [ { "message": "...", "paths": ["dir", "file"] } ] }`, with each message composed by `git-commit` and each path a file or directory whose final state belongs to that commit. A file that a generator or test reads belongs with the code that reads it.
2. **Run step 2 regroup.** It checks every message first, keeps the branch under a `backup/` ref, commits each group from the final tree, and refuses a plan that leaves a change uncovered or alters the tree. Any failure restores the branch.
3. **Check each commit on its own** in a separate worktree that reuses the build cache: the host's build at every commit, and the tests of the parts a commit completes. Move paths between groups and re-run step 2 until each commit builds.
4. **Finish** with step 4 `-Mode Commits`, and tell the user the `backup/` branch is theirs to delete.

## RebaseMerge

The base is never pushed directly and never gains a merge commit; the platform's rebase and merge appends the branch's commits to it. Those are never the commits the branch was built with: they are a work log and can be messy, so the request always carries a regrouped history.

1. **Regroup the commits** before step 4, every time, into at most five logical commits as described above; ask how many only within that limit. Never push the branch's own commits as they are.
2. **Open the request** with step 4 `-Mode RebaseMerge`.
3. **Fix CI on the branch** — watch the request's checks, read the failed logs, and push each fix as a new commit, until every check passes. A check that fails once and passes on a re-run of the failed job, with no change, is flaky: report it as follow-up work rather than patching around it.
4. **Wait for the user's word to merge.** A green request is not permission to land it.
5. **Fold the fix commits** into the regrouped commits they correct with fixups. This rewrites history without changing the tree.
6. **Run step 5** with `-TestedCommit` set to the commit CI passed. It refuses a tree that differs from the tested one or a commit whose CI did not pass, force-pushes a rewritten branch and cancels the CI runs that push starts, merges with `gh pr merge --rebase --delete-branch`, and fast-forwards the local base.

The base's own CI still runs after the merge; report it rather than cancelling it.

## For humans — use the interactive script

Run `pwsh <skill>/scripts/integrate.ps1 -CleanBranchSkill <dev-workflow-clean-branch> -ConventionCommitMessageSkill <convention-commit-message>` and follow its prompts. It asks the mode question and refuses to proceed until it is answered.
