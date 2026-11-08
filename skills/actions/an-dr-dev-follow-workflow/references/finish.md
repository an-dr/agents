# Share and finish

- `.progress/workflow.json` is committable: include it in checkpoint and increment commits, which the work branch's automatic push carries to the remote; never add `.progress/` to an ignore file.
- State-changing commands regenerate `.progress/PROGRESS.md`, a human snapshot without IDs (flow, phase, goal, requests, iterations with statuses, questions with answers); read it for quick status instead of parsing JSON.
- `finish` deletes both files at `INTEGRATE`, before integration. Commit the deletion; `an-dr-dev-integrate`'s `remove-progress.ps1` then keeps `.progress/` out of every delivered feature-branch commit.
