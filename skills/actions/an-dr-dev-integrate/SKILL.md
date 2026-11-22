---
name: an-dr-dev-integrate
description: Integrate a branch into its base — the branch it started from, else the default branch — through its pull or merge request with the repository's merge method, or locally by rebasing and keeping, regrouping, or squashing its commits when no platform is available. Use only when the user explicitly asks to integrate, merge, or land a branch, or to open a request or address its review comments.
license: MIT
allowed-tools: Read Grep Glob Bash Python
metadata:
  author: Andrei Gramakov (an-dr)
  version: "5.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-use-user-interface an-dr-ai-use-wip-data an-dr-convention-commit-message an-dr-git-modify-history
---

# Integrate

Defers: questions to `an-dr-ai-use-user-interface`; the state to `an-dr-ai-use-wip-data`; messages to `an-dr-git-modify-history`, checked by `an-dr-convention-commit-message`.

## When it runs

- Integration itself only on the user's explicit request in their own words; a finished review, an accepted delivery, or green checks are not that request. Confirm the branch and its base with one `an-dr-ai-use-user-interface` confirmation before anything changes.
- It integrates whatever branch it is given. The base is `-BaseBranch` when given, else `workflow.baseBranch` of the handed-over state read through `an-dr-ai-use-wip-data`, else the branch config `branch.<name>.an-dr-base` that step 3 writes before dropping the state, else the default branch.
- It changes no commit to make a branch landable. Step 3 drops the `DO-NOT-MERGE:` commits at the tip by moving the branch back past them; steps 2, 4, and 5 refuse while any remains.
- Steps 1 and 3 refuse a branch the handover did not leave clean: a revert (`Revert "…"`, a `revert:` type, or a `This reverts commit` line), a `DO-NOT-MERGE:` commit below work that lands or changing files beyond `tmp-` ones, or a `tmp-`/`.tmp-` file in a commit that lands. Report the refusal; the fix belongs to the branch's owner.
- Opening a request and addressing review comments need only the user's ask for them: they change nothing on the base.

## Through the request

A branch with a pull or merge request integrates through it whenever the platform allows. Read [references/pull-request.md](references/pull-request.md) when opening one, when the user says to address the comments, and at integration.

## Ask the local mode

Only when the request path is unavailable, and after saying what is missing. Before asking, read [references/modes.md](references/modes.md).

- Ask every time, as the first step, before a rebase or any history change; never answer it yourself.
- Approval to integrate is not a mode choice; the last mode used is not a default.
- One `an-dr-ai-use-user-interface` question, the three local modes as options (`Commits`, `Regroup`, `Squash`), no recommendation; wait for the answer.

## Run the steps

Scripts are in `<skill>/scripts/`; each exits non-zero on failure. `<an-dr-convention-commit-message>` and `<an-dr-ai-use-wip-data>` are those skills' folders, wherever they were loaded from; scripts take them as parameters instead of guessing. Every step also takes `--wip-data-skill <an-dr-ai-use-wip-data>`, left out of the table.

| Step                                  | Command                                                                                                                                                                           |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 — check state                       | `python integrate-1-check.py [--base-branch <name>]`                                                                                                                              |
| 2 — squash commits (optional)         | `python integrate-2-squash.py --hash <hash> --message '<msg>' --commit-message-skill <an-dr-convention-commit-message> [--base-branch <name>]`                                    |
| 2 — regroup commits (`Regroup` only)  | `python integrate-2-regroup.py --plan <plan.json> --commit-message-skill <an-dr-convention-commit-message> [--base-branch <name>]`                                                |
| 3 — rebase                            | `python integrate-3-rebase.py [--base-branch <name>]`                                                                                                                             |
| 4 — finish                            | `python integrate-4-finish.py --mode <Commits\|Squash\|Request\|RebaseMerge> [--message '<msg>' --commit-message-skill <an-dr-convention-commit-message>] [--base-branch <name>]` |
| 5 — rebase-merge (`RebaseMerge` only) | `python integrate-5-rebase-merge.py --tested-commit <sha> [--base-branch <name>]`                                                                                                 |

1. Run step 1. Check the recent log for WIP commits and the base-to-HEAD log for topic commits.
2. Run step 3 (drop the `DO-NOT-MERGE:` tip, fetch, rebase); fix conflicts where it pauses.
3. WIP commits at the tip → step 2 squash, `<hash>` = the commit before the first WIP, with a clean message.
4. Run step 1 again, then:
   - `Commits` → step 4 `--mode Commits`.
   - `Squash`, `Request` → step 4 with `--message`; it collapses itself, step 2 is not rerun. Compose the message with `an-dr-git-modify-history`; it is validated before anything is rewritten.
   - `Regroup` → read [references/regroup.md](references/regroup.md), then step 4 `--mode Commits`.
   - `RebaseMerge` → read [references/rebase-merge.md](references/rebase-merge.md).

## Interactive script

For a human: `python <skill>/scripts/integrate.py --commit-message-skill <an-dr-convention-commit-message> --wip-data-skill <an-dr-ai-use-wip-data>`; it asks the mode and refuses to proceed without an answer.

## Rules

- Local modes always rebase first and never add a merge commit; the request path uses the repository's configured merge method, merge commits included.
- `integrate-4-finish.py` makes `--mode` mandatory so no run skips the question.
