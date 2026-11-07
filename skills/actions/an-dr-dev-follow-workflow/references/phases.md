# Work by phase

- DOCS → `an-dr-dev-write-documentation`, starting with any DESIGN specification; new project → README via `an-dr-dev-write-readme`; leave it uncommitted for the increment's COMMIT.
- BUILD → `an-dr-dev-implement-code`, only the selected Quick option or active increment.
- VERIFY → `an-dr-dev-test` for changed code, `an-dr-dev-review` for the diff; per increment only fast checks (build, lint, tests of what it touched); docs-only → sources, links, consistency via `an-dr-dev-write-documentation`; report failure cases, untested edges, doc gaps, scope, consistency; issues → BUILD, after `an-dr-dev-debug` when a cause is not evident.
- Branch tests → after the last known increment's commit, before `SUMMARY`: tests of everything the branch touched, scoped by `an-dr-dev-test`, full suite only when that skill calls for it; fix each failure with a fixup into the increment that introduced it, so each increment stays one reviewable commit; a later increment reopens this step once committed.
- COMMIT → `an-dr-git-commit`, including current progress state.
- SUMMARY → `an-dr-dev-analyze-changes` for the full branch: review, reconcile with intake requests, hand over the summary.
- INTEGRATE → after approval: `finish`, commit the deletion, then `an-dr-dev-integrate` (removes `.progress/` from the branch) and ask for its mode.
