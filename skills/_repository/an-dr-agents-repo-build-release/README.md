# an-dr-agents-repo-build-release

Versions this repository and publishes it as a package, so a user can take a known version of the policy and its skills instead of whatever a branch holds today.

## When it runs

- You ask for a release of this repository.
- You want to see what a package would contain.

## How it works

The version lives in `VERSION` at the root, and each release has notes in `docs/releases/<version>.md`. `scripts/package.py` builds `agents-<version>.zip`: the policy (`AGENTS.md`), `README.md`, `VERSION`, `LICENSE`, and every skill except those under `skills/_repository`, which only maintain this repository. Pushing a `v<version>` tag makes `.github/workflows/release.yml` rerun every check, package, and publish the GitHub release with the notes, the zip, and its checksum.

## What you get

- `agents-<version>.zip` and `SHA256SUMS` on the GitHub release for the tag.

## Related

- [an-dr-git-modify-history](../../actions/an-dr-git-modify-history/README.md) — records the release commit.
