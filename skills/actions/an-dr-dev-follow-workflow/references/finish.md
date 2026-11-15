# Share and finish

- `.progress/workflow.json` is committable: include it in checkpoint and increment commits, which the work branch's automatic push carries to the remote; never add `.progress/` to an ignore file.
- State-changing commands regenerate `.progress/PROGRESS.md`, a human snapshot without IDs (flow, phase, goal, requests, iterations with statuses, questions with answers); read it for quick status instead of parsing JSON.
- `finish` runs last in `HANDOVER`, after `remove-progress.ps1` has stripped `.progress/` from the branch history, and refuses while any branch commit still holds it. It deletes the local files and the progress page; on the base branch (`-OnBase`) commit the deletion if `.progress/` was committed.
