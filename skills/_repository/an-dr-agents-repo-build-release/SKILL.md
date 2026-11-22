---
name: an-dr-agents-repo-build-release
description: Version this repository and publish it as a release - VERSION, release notes, the agents-<version>.zip package without the repository-only skills, and the tag that makes CI publish it. Use when the user asks for a release or pre-release of this repository, for its branch and tag rules, or to check what a package would contain.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.2.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-use-user-interface an-dr-git-modify-history
---

# Build a release

Owns: `VERSION`, `docs/releases/<version>.md`, `scripts/package.py`, `scripts/promote.py`, and `.github/workflows/release.yml`. Amendments reach `dev` first; `main` moves only here.

## Branches and tags

- `dev` is the integration branch: every amendment and every contribution targets it.
- `main` receives only promoted release commits, by fast-forward, plus maintainer hotfixes. A hotfix branches from `main`, is released as a patch, and `main` is then merged back into `dev` so the next promotion fast-forwards again.
- A release is tagged `v<version>` on `main`; a pre-release is tagged `v<version>-pre.<n>` on `dev`, `<n>` counting from 1, and is published as a GitHub pre-release that never becomes the latest release.
- `VERSION` holds the version in progress, without the pre-release suffix, so the final release ships the commit its last pre-release tested.
- Published history is never rewritten: no force-push to `main` or `dev`, and no moved or deleted tags.

## The package

`agents-<label>.zip`, where `<label>` is the tag without its `v`, holds one folder, `agents-<label>/`, with `AGENTS.md`, `README.md`, `VERSION`, `LICENSE`, `skills/README.md`, and every skill category except `skills/_repository`, whose skills only maintain this repository. `SHA256SUMS` beside it lists the zip's checksum.

```sh
python <skill>/scripts/package.py [--out-directory <folder>] [--tag v<version>[-pre.<n>]]
python <skill>/scripts/check-main-staleness.py [--root <clone>] [--max-days 14] [--max-commits 20]
```

- The staleness check prints days since `main` moved and the `dev` commits not on `main`; it exits 1 when `dev` is ahead and either limit is passed, and 2 when a branch is missing.
- Prints the zip's path. `-Tag` refuses a tag other than `v<VERSION>` or `v<VERSION>-pre.<n>` and a missing `docs/releases/<version>.md`, the checks CI runs.

## Release

Only on the user's request, and after the release is confirmed as an `an-dr-ai-use-user-interface` confirmation naming the version.

1. Keep the version a pre-release already set in `VERSION`; otherwise pick it by semantic versioning against the last release tag: a removed or renamed skill, a changed script parameter, or a policy rule a user must follow differently is major; a new skill, flow, or capability is minor; anything else is patch.
2. Raise `version` in each skill whose behaviour changed since the last release tag, by the same semantic rule; a skill a pre-release of this cycle already raised keeps that version.
3. Write or complete `VERSION` and `docs/releases/<version>.md`, covering the whole cycle rather than the last pre-release: one opening sentence on what the release gives, then one bullet per user-visible change, in the user's terms.
4. Run `python <skill>/scripts/package.py --tag v<version>` and the repository checks, then commit them with the raised skill versions through `an-dr-git-modify-history` as `chore: release <version>` on `dev`, and push `dev`.
5. Promote the release commit with `python <skill>/scripts/promote.py`: from a clean `dev` whose tip descends from `main`, it runs `tests/run-all.py --all` on that commit, fast-forwards `main`, and pushes `main` and `dev`; it never force-pushes. Then tag `main` and push the tag: `git tag v<version>` and `git push origin v<version>`. `release.yml` reruns every check, packages, and publishes the GitHub release with the notes, the zip, and `SHA256SUMS`.
6. Report the release URL, or the failing step of the release run.

## Pre-release

Only on the user's request, confirmed as an `an-dr-ai-use-user-interface` confirmation naming the tag. No promotion: `main` stays where it is.

1. If `VERSION` still equals the last release, pick the next version as in Release step 1 and commit `VERSION` with `docs/releases/<version>.md` on `dev`; otherwise add the changes since the previous pre-release to those notes. A breaking change in a minor cycle moves `VERSION` to the next major. In both cases raise skill versions as in Release step 2.
2. Take the next `<n>` from the existing `v<version>-pre.*` tags, run `python <skill>/scripts/package.py --tag v<version>-pre.<n>` and the repository checks, push `dev`, then `git tag v<version>-pre.<n>` on the `dev` tip and `git push origin v<version>-pre.<n>`.
3. Report the pre-release URL, or the failing step of the release run.
