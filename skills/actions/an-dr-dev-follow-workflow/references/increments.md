# Changing increments

- `move-increment` reorders or inserts only planned increments. Completed increments keep immutable IDs and fixed positions; renumbering never changes which increment is active.
- `defer-increment` is the only way the active increment changes position: priorities move an untouched increment later, never to escape one under way.
  - Returns the active increment to `planned` at `-To`, starts the first planned increment, stays in `BUILD`.
  - Requires a clean working tree; refuses when no planned increment remains.
  - The clean tree is the controller's only evidence nothing was built; it cannot see committed work, so never defer an increment whose commits are on the branch.
  - IDs survive, so history and approvals stay attached.
- `remove-increment` drops work the user decided against.
  - A completed increment is delivered history and cannot be removed.
  - The active one can be, under the same BUILD-and-clean-tree rule; the next planned increment starts, or the flow moves to `SUMMARY` when none remains.
  - Record why in the response; it is a scope change the plan no longer explains.
- `add-increment` in `SUMMARY` or `FINAL_REVIEW` for newly found work drops the `implement` and `integrate` approvals and returns to `SPLIT`, so the enlarged plan is authorised again before the new work passes the branch cycle.
