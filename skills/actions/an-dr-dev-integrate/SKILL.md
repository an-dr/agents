---
name: an-dr-dev-integrate
description: Integrate a branch into its base — the branch it started from, else the default branch — through its pull or merge request with the repository's merge method, or locally by rebasing and keeping, regrouping, or squashing its commits when no platform is available. Use only when the user explicitly asks to integrate, merge, or land a branch; also opens draft requests and addresses review comments.
license: MIT
allowed-tools: Read Grep Glob Bash Python
metadata:
  author: Andrei Gramakov (an-dr)
  version: "4.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-use-user-interface an-dr-ai-use-wip-data an-dr-convention-commit-message an-dr-git-modify-history
---

# Integrate

Defers: questions to `an-dr-ai-use-user-interface`; messages to `an-dr-git-modify-history`, checked by `an-dr-convention-commit-message`.

## When it runs

- Integration itself only on the user's explicit request in their own words; a finished review, an accepted delivery, or green checks are not that request. Confirm the branch and its base with one `an-dr-ai-use-user-interface` confirmation before anything changes.
- It integrates whatever branch it is given. The base is `-BaseBranch` when given, else the branch it started from — the branch config `branch.<name>.an-dr-base`, or `workflow.baseBranch` in `tmp-agent-wip.json` read through `an-dr-ai-use-wip-data` — else the default branch. The workflow controller writes that branch config when the work branch is created, and step 3 writes it again before stripping the file.
- Files and folders whose names start with `tmp-` or `.tmp-` never land: step 3 strips them from every commit after the base, drops commits that held nothing else, and deletes them from disk; steps 4 and 5 refuse while any remains.
- Opening a draft request and addressing review comments need no such request: they change nothing on the base.

## Through the request

A branch with a pull or merge request integrates through it whenever the platform allows. Read [references/pull-request.md](references/pull-request.md) when opening one, when the user says to address the comments, and at integration.

## Ask the local mode

Only when the request path is unavailable, and after saying what is missing. Before asking, read [references/modes.md](references/modes.md).

- Ask every time, as the first step, before a rebase or any history change; never answer it yourself.
- Approval to integrate is not a mode choice; the last mode used is not a default.
- One `an-dr-ai-use-user-interface` question, the three local modes as options (`Commits`, `Regroup`, `Squash`), no recommendation; wait for the answer.

## Run the steps

Scripts are in `<skill>/scripts/`; each exits non-zero on failure. `<an-dr-convention-commit-message>` is that convention's folder, wherever it was loaded from; scripts take it as a parameter instead of guessing.

| Step                                  | Command                                                                                                                                                                           |
| ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 — check state                       | `python integrate-1-check.py [--base-branch <name>]`                                                                                                                              |
| 2 — squash commits (optional)         | `python integrate-2-squash.py --hash <hash> --message '<msg>' --commit-message-skill <an-dr-convention-commit-message> [--base-branch <name>]`                                    |
| 2 — regroup commits (`Regroup` only)  | `python integrate-2-regroup.py --plan <plan.json> --commit-message-skill <an-dr-convention-commit-message> [--base-branch <name>]`                                                |
| 3 — rebase                            | `python integrate-3-rebase.py [--base-branch <name>]`                                                                                                                             |
| 4 — finish                            | `python integrate-4-finish.py --mode <Commits\|Squash\|Request\|RebaseMerge> [--message '<msg>' --commit-message-skill <an-dr-convention-commit-message>] [--base-branch <name>]` |
| 5 — rebase-merge (`RebaseMerge` only) | `python integrate-5-rebase-merge.py --tested-commit <sha> [--base-branch <name>]`                                                                                                 |

Every script also takes `--wip-data-skill <an-dr-ai-use-wip-data>`, through which it reads the base the work started from.

1. Run step 1. Check the recent log for WIP commits and the base-to-HEAD log for topic commits.
2. WIP commits at the tip → step 2 squash, `<hash>` = the commit before the first WIP, with a clean message.
3. Run step 3 (fetch + rebase); fix conflicts where it pauses.
4. Run step 1 again, then:
   - `Commits` → step 4 `--mode Commits`.
   - `Squash`, `Request` → step 4 with `--message`; it collapses itself, step 2 is not rerun. Compose the message with `an-dr-git-modify-history`; it is validated before anything is rewritten.
   - `Regroup` → read [references/regroup.md](references/regroup.md), then step 4 `--mode Commits`.
   - `RebaseMerge` → read [references/rebase-merge.md](references/rebase-merge.md).

## Interactive script

For a human: `python <skill>/scripts/integrate.py --commit-message-skill <an-dr-convention-commit-message>`; it asks the mode and refuses to proceed without an answer.

## Rules

- Local modes always rebase first and never add a merge commit; the request path uses the repository's configured merge method, merge commits included.
- `integrate-4-finish.py` makes `--mode` mandatory so no run skips the question.
