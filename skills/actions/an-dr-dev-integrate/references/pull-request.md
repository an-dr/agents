# Pull request path

The default integration for a branch on a supported platform. "Request" means a GitHub pull request, a GitLab merge request, or whatever the remote's platform calls it.

## Detect the platform

- `gh auth status` succeeds and `origin` is on GitHub → GitHub through `gh`.
- `glab auth status` succeeds and `origin` is on GitLab → GitLab through `glab`.
- Anything else (no remote, no CLI, no authentication, another platform) → name what is missing and use the local modes instead.

## Open it

- When the user asks to integrate the branch, or to open a request for it: `gh pr create --fill --base <base>` or `glab mr create --fill --target-branch <base>`, with the change summary in the description and any change report attached or linked.
- One request per branch; later commits are pushed to it, so platform CI runs on each.

## Address review comments

When the user says to address the comments:

1. Read every unresolved thread (`gh pr view --comments`, or `gh api` for review threads; `glab mr note list`).
2. Fix each one with a new commit; never rewrite history while the request is open, so the threads stay attached to the lines they discuss.
3. Reply to each thread with what changed, or why it was not changed, and resolve the ones that are fixed.
4. Push, then tell the user which threads were fixed, answered, or left open.

## Merge

Only on the user's explicit request to integrate:

1. Run steps 1 and 3 of the skill (check, then drop the `DO-NOT-MERGE:` tip and rebase); if the history is still a work log, regroup once as in [regroup.md](regroup.md). Push with `--force-with-lease`.
2. Wait for checks to pass on the pushed commit; a failing check goes back to the user, never merged around.
3. Merge with the repository's own merge method:
   - GitLab: `glab mr merge --remove-source-branch` applies the project's configured method.
   - GitHub has no single default: read `gh repo view --json mergeCommitAllowed,rebaseMergeAllowed,squashMergeAllowed`. Exactly one allowed → use it. Several → ask the user which of the allowed methods, as one `an-dr-ai-use-user-interface` question. Then `gh pr merge --<method> --delete-branch`.
4. Fast-forward the local base to the merged result and delete the local branch.
