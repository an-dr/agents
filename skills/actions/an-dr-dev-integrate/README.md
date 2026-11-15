# an-dr-dev-integrate

Lands a branch on the default branch when you ask for it, normally through its pull or merge request, and locally only when no platform is available. It does not know which workflow, if any, produced the branch.

## When it runs

- At a branch's first push, to open a draft request.
- When you say to address the request's review comments.
- When you ask to integrate, merge, or land a branch, and only then.

## How it works

```mermaid
flowchart TD
  P[First push of the work branch] --> D{gh or glab, remote, and auth available?}
  D -- yes --> R[Draft pull or merge request]
  R --> I[Each increment pushed, CI runs]
  I --> F[Marked ready with summary and change report]
  F --> C{Your review}
  C -- comments --> X[Agent fixes, replies, resolves]
  X --> F
  C -- you ask to integrate --> M[Rebase, regroup if needed, wait for checks]
  M --> G[Merge with the repository's merge method]
  D -- no --> L[Say what is missing]
  L --> Q[Ask: Commits, Regroup, or Squash]
  Q --> LL[Rebase and fast-forward locally]
```

- **Review in the request.** Your comments sit on the lines they discuss. The agent answers each thread and resolves the ones it fixed. While the request is open it only adds commits, so your threads never go stale.
- **Merge method.** The request merges the way the repository is configured. GitLab applies its project setting. GitHub has no single default, so if several methods are allowed, the agent asks which one.
- **Local fallback.** Without a platform, the agent rebases and asks you each time whether to keep every commit, regroup them into a few, or squash into one. It never adds a merge commit locally.
- **Any branch.** It takes the branch as it is; cleaning up after a workflow is that workflow's job, done before the branch is handed over.

## What you get

- One pull or merge request per branch, with CI on every push and a description that links the change report.
- After the merge: the base fast-forwarded locally, the work branch deleted locally and on the remote.

## What you decide

- Whether to integrate at all: nothing lands until you ask; a green CI run or an accepted review is not permission.
- The merge method, only when GitHub allows several.
- The local mode, only on the fallback path.

## Related skills

- [an-dr-dev-follow-workflow](../an-dr-dev-follow-workflow/README.md) — hands over a cleaned branch, ready for this skill.
- [an-dr-git-modify-history](../an-dr-git-modify-history/README.md) — regrouping and commit messages.
