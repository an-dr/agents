# Work by phase

- DOCS → `an-dr-dev-write-documentation`, starting with any DESIGN specification; new project → README via `an-dr-dev-write-readme`; leave it uncommitted for the increment's COMMIT.
- BRANCH → create `spec/<slug>` or `supervised/<slug>` from the base (Spec-driven `-OnBase` stays on the base); the first push opens a draft pull or merge request, see `an-dr-dev-integrate`.
- BUILD → `an-dr-dev-implement-code`, only the active increment.
- VERIFY → `an-dr-dev-test` for changed code, `an-dr-dev-review` for the diff; per increment only fast checks (build, lint, tests of what it touched); docs-only → sources, links, consistency via `an-dr-dev-write-documentation`; report failure cases, untested edges, doc gaps, scope, consistency; issues → BUILD, after `an-dr-dev-debug` when a cause is not evident.
- Branch tests → after the last known increment's commit, before `SUMMARY`: tests of everything the branch touched, scoped by `an-dr-dev-test`, full suite only when that skill calls for it; fix each failure with a fixup into the increment that introduced it, so each increment stays one reviewable commit; a later increment reopens this step once committed.
- COMMIT → `an-dr-git-modify-history`, including current progress state; push the work branch.
- SUMMARY → `an-dr-dev-analyze-changes` for the full branch: review, reconcile with intake requests, mark the request ready, hand over the summary with its link.
- SUMMARY and FINAL_REVIEW → when the user says to address the request's comments, follow `an-dr-dev-integrate`'s comment handling, then report what changed.
- HANDOVER → after `accept`, leave a branch anyone can integrate, then stop:
  1. Commit the current progress state, then regroup the branch once with `an-dr-git-modify-history`: fixups folded, superseded commits dropped, one commit per logical change.
  2. `pwsh <skill>/scripts/remove-progress.ps1 [-BaseBranch <base>]` strips `.progress/` from every branch commit and prunes progress-only commits; rerun the branch tests if a rewritten commit was never tested at its final content.
  3. Remove other leftovers the flow created in the branch: scratch files, generated artifacts that are not repository content.
  4. Push with `--force-with-lease`; the request stays ready, with the change report linked.
  5. `finish`; it refuses while the branch still carries `.progress/`, then deletes the local state and the progress page.
  6. Tell the user the branch is ready and that `an-dr-dev-integrate` lands it when they ask. Never integrate from here.
