# Contributing

## Branches

Open pull requests against `dev`, never `main`. `main` only receives promoted releases and maintainer hotfixes, so a pull request to it is retargeted to `dev` before review. The [release skill](skills/_repository/an-dr-agents-repo-build-release/SKILL.md) owns the branch and tag rules.

## Changes

- Follow [AGENTS.md](AGENTS.md) for changes to this repository.
- Use the [skill convention](skills/conventions/an-dr-convention-agent-skill/SKILL.md) when changing skills.
- Keep generated artifacts out of commits.
- This repository keeps no ADRs: state every decision in the skill or policy that owns it, so the skills and [AGENTS.md](AGENTS.md) are the record.

## Checks

Run the repository checks before proposing a change:

```sh
python tests/run-all.py
```
