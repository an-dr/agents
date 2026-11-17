# Share and finish

- `tmp-agent-wip.json` is committable: commit it at each checkpoint in its own `DO-NOT-MERGE: <summary>` commit, never mixed with work, which the work branch's automatic push carries to the remote; never add it to an ignore file. A state from before the move, `.progress/workflow.json`, is moved to the root by the next command.
- Every path whose name starts with `tmp-` or `.tmp-` is a work file. It travels on the work branch until the handover strips it from the work commits.
- `finish` runs in `HANDOVER` after the result is approved, in every flow. It marks the state handed over and keeps it; committed as the branch's one `DO-NOT-MERGE:` commit, it names the base for `an-dr-dev-integrate` on any machine.
