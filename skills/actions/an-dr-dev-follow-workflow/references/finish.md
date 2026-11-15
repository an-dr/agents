# Share and finish

- `tmp-agent-wip.json` is committable: include it in checkpoint and increment commits, which the work branch's automatic push carries to the remote; never add it to an ignore file. A state from before the move, `.progress/workflow.json`, is moved to the root by the next command.
- Every path whose name starts with `tmp-` or `.tmp-` is a work file. It may travel on the work branch; `an-dr-dev-integrate` strips it from every commit and refuses to land while one remains, so nothing else needs to remove it.
- `finish` runs last in `HANDOVER`. On a work branch it marks the state handed over and keeps it, since `an-dr-dev-integrate` reads the base from it; commit that change. On the base branch (`--on-base`) it deletes the state; commit the deletion. Vibe has no `finish`: landing performs it.
