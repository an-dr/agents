# Share and finish

- `.progress/workflow.json` is committable: include it in checkpoint and increment commits; push when work moves machines; never add `.progress/` to an ignore file.
- State-changing commands regenerate `.progress/PROGRESS.md`, a human snapshot without IDs (flow, phase, goal, requests, iterations with statuses, questions with answers); read it for quick status instead of parsing JSON.
- `finish` deletes both files: at Quick/COMMIT before the final commit, at Detailed/INTEGRATE before integration. Commit the deletion; `an-dr-dev-integrate`'s `remove-progress.ps1` then keeps `.progress/` out of every delivered feature-branch commit.
