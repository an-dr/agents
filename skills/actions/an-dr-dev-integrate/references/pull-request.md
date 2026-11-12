# Pull request path

The default integration for Spec-driven and Supervised work branches. "Request" means a GitHub pull request, a GitLab merge request, or whatever the remote's platform calls it.

## Detect the platform

- `gh auth status` succeeds and `origin` is on GitHub → GitHub through `gh`.
- `glab auth status` succeeds and `origin` is on GitLab → GitLab through `glab`.
- Anything else (no remote, no CLI, no authentication, another platform) → name what is missing and use the local modes instead.

## Open it early

- At the work branch's first push: `gh pr create --draft --fill --base <base>` or `glab mr create --draft --fill --target-branch <base>`.
- One request per workflow, never one per increment. Each increment's commit is pushed to it, so platform CI runs per increment.
- At SUMMARY or FINAL_REVIEW: put the change summary in the description, attach or link the change report, and mark it ready (`gh pr ready`, `glab mr update --ready`).

## Address review comments

When the user says to address the comments:

1. Read every unresolved thread (`gh pr view --comments`, or `gh api` for review threads; `glab mr note list`).
2. Fix each one with a new commit; never rewrite history while the request is open, so the threads stay attached to the lines they discuss.
3. Reply to each thread with what changed, or why it was not changed, and resolve the ones that are fixed.
4. Push, then tell the user which threads were fixed, answered, or left open.

## Merge

Only after the `integrate` approval:

1. Run step 0 to remove `.progress/`, then regroup once as in [regroup.md](regroup.md) if the branch history is a work log, and rebase onto the base. Push with `--force-with-lease`.
2. Wait for checks to pass on the pushed commit; a failing check goes back to the user, never merged around.
3. Merge with the repository's own merge method:
   - GitLab: `glab mr merge --remove-source-branch` applies the project's configured method.
   - GitHub has no single default: read `gh repo view --json mergeCommitAllowed,rebaseMergeAllowed,squashMergeAllowed`. Exactly one allowed → use it. Several → ask the user which of the allowed methods, as one `an-dr-ai-use-user-interface` question. Then `gh pr merge --<method> --delete-branch`.
4. Fast-forward the local base to the merged result and delete the local branch.
