# RebaseMerge

The base is never pushed directly and never gains a merge commit; the platform's rebase and merge appends the branch's commits. Branch commits are a work log, so the request always carries a regrouped history.

1. Regroup every time before step 4, into at most five logical commits, as in [regroup.md](regroup.md); ask how many only within that limit. Never push the branch's own commits as they are.
2. Open the request with step 4 `-Mode RebaseMerge`.
3. Watch the request's checks, read failed logs, push each fix as a new commit until every check passes. A check that fails once and passes on a rerun of the failed job with no change is flaky → report it as follow-up work, do not patch around it.
4. Wait for the user's word to merge; a green request is not permission.
5. Fold the fix commits into the regrouped commits they correct with fixups; the tree does not change.
6. Run step 5 with `-TestedCommit` = the commit CI passed. It refuses a tree differing from the tested one or a commit whose CI did not pass, force-pushes a rewritten branch and cancels the CI runs that push starts, merges with `gh pr merge --rebase --delete-branch`, and fast-forwards the local base.

The base's own CI still runs after the merge; report it, do not cancel it.
