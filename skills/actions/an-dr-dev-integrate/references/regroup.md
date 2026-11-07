# Regroup

Ask how many commits when the answer did not say.

1. Plan the commits in dependency order, each building on the ones before: typically the contract or library, then its users, then tools, then documentation. Write the plan as JSON, `{ "commits": [ { "message": "...", "paths": ["dir", "file"] } ] }`; each message composed by `an-dr-git-commit`, each path a file or directory whose final state belongs to that commit. A file a generator or test reads goes with the code that reads it.
2. Run step 2 regroup. It checks every message first, keeps the branch under a `backup/` ref, commits each group from the final tree, and refuses a plan that leaves a change uncovered or alters the tree; any failure restores the branch.
3. Check each commit alone in a separate worktree reusing the build cache: the host's build at every commit, and the tests of the parts a commit completes. Move paths between groups and rerun step 2 until each commit builds.
4. Finish with step 4 `-Mode Commits`; tell the user the `backup/` branch is theirs to delete.
