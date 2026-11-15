---
name: an-dr-agents-repo-build-release
description: Version this repository and publish it as a release - VERSION, release notes, the agents-<version>.zip package without the repository-only skills, and the tag that makes CI publish it. Use when the user asks for a release of this repository, or to check what a package would contain.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-use-user-interface an-dr-git-modify-history
---

# Build a release

Owns: `VERSION`, `docs/releases/<version>.md`, `scripts/package.py`, `scripts/promote.py`, and `.github/workflows/release.yml`. Amendments reach `dev` first; `main` moves only here.

## The package

`agents-<version>.zip` holds one folder, `agents-<version>/`, with `AGENTS.md`, `README.md`, `VERSION`, `LICENSE`, `skills/README.md`, and every skill category except `skills/_repository`, whose skills only maintain this repository. `SHA256SUMS` beside it lists the zip's checksum.

```sh
python <skill>/scripts/package.py [--out-directory <folder>] [--tag v<version>]
python <skill>/scripts/check-main-staleness.py [--root <clone>] [--max-days 14] [--max-commits 20]
```

- The staleness check prints days since `main` moved and the `dev` commits not on `main`; it exits 1 when `dev` is ahead and either limit is passed, and 2 when a branch is missing.
- Prints the zip's path. `-Tag` refuses a tag other than `v<VERSION>` and a missing `docs/releases/<version>.md`, the checks CI runs.

## Release

Only on the user's request, and after the release is confirmed as an `an-dr-ai-use-user-interface` confirmation naming the version.

1. Pick the version by semantic versioning against the last tag: a removed or renamed skill, a changed script parameter, or a policy rule a user must follow differently is major; a new skill, flow, or capability is minor; anything else is patch.
2. Write `VERSION` and `docs/releases/<version>.md`: one opening sentence on what the release gives, then one bullet per user-visible change, in the user's terms.
3. Run `python <skill>/scripts/package.py --tag v<version>` and the repository checks, then commit both files through `an-dr-git-modify-history` as `chore: release <version>` on `dev`, and push `dev`.
4. Promote the release commit with `python <skill>/scripts/promote.py`: from a clean `dev` whose tip descends from `main`, it runs `tests/run-all.py --all` on that commit, fast-forwards `main`, and pushes `main` and `dev`; it never force-pushes. Then tag `main` and push the tag: `git tag v<version>` and `git push origin v<version>`. `release.yml` reruns every check, packages, and publishes the GitHub release with the notes, the zip, and `SHA256SUMS`.
5. Report the release URL, or the failing step of the release run.
