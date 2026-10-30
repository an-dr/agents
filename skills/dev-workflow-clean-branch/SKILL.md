---
name: dev-workflow-clean-branch
description: Remove `.progress/` from every commit on a linear workflow feature branch, preserving non-progress content and commit metadata while pruning commits that become empty. Use before integrating a workflow feature branch.
metadata:
  dependencies: none
---

# Remove workflow progress from history

Run this after the workflow's `finish` operation and committing the resulting deletion, before integration. The script rewrites only commits after the merge base with the repository's default branch; default-branch history is never changed.

```powershell
pwsh <skill>/scripts/remove-progress.ps1 [-BaseBranch <name>]
```

The feature branch must be linear and the working tree clean. The script:

1. removes `.progress/` from every feature-branch commit;
2. preserves each remaining commit's message, author, committer, and dates;
3. prunes commits whose only content was workflow progress;
4. verifies that neither the final tree nor feature-branch history contains `.progress/`.

Run the relevant tests again if rewritten commits have not already been verified at their final content.
