# Work by stage

- BRANCH → create the work branch from the base, named by `an-dr-convention-branch-name`.
- DOCS → `an-dr-dev-write-documentation`, starting with any DESIGN specification draft, written as the final documents and then deleted; new project → README via `an-dr-dev-write-readme`; leave it uncommitted for the iteration's COMMIT.
- BUILD → `an-dr-dev-implement-code` for the active iteration only, with its DOCS output as the specification; a documentation gap is reported, not filled in code; a conflict between docs and code becomes a question; no commit until COMMIT.
- VERIFY → `an-dr-dev-test` for changed code, `an-dr-dev-review` for the iteration's changes; Supervised: the user approves the iteration, otherwise record the verdict; per iteration only fast checks (build, lint, tests of what it touched); docs-only → sources, links, consistency via `an-dr-dev-write-documentation`; issues → BUILD, after `an-dr-dev-debug` when a cause is not evident.
- Branch tests → after the last iteration's commit, before `SUMMARY`: tests of everything the branch touched, scoped by `an-dr-dev-test`; fix each failure with a fixup into the iteration that introduced it.
- COMMIT → `an-dr-git-modify-history`, with the current progress state in its own `DO-NOT-MERGE:` commit; push the work branch. Pass the base as `-Range <base>..HEAD`, `<base>` being the `Base:` line of `status`.
- HANDOVER → after the result is approved, leave a branch ready to integrate, then stop:
  1. Regroup the branch once with `an-dr-git-modify-history`: fixups folded, superseded commits dropped, one commit per logical change.
  2. Remove leftovers the flow created that are not repository content.
  3. Strip every `tmp-` file from the work commits: `python <an-dr-git-modify-history>/scripts/strip-tmp-files.py --base <base>`; the files stay on disk, untracked.
  4. `finish`: it marks the state handed over.
  5. Commit `tmp-agent-wip.json` alone through `an-dr-git-modify-history` as `DO-NOT-MERGE: hand over <branch>`.
  6. Push with `--force-with-lease`, and tell the user the branch is ready to integrate when they ask.
