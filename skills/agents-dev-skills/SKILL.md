---
name: agents-dev-skills
description: Create, rename, or restructure a skill in this agents repository — its directory, frontmatter, scripts and their tests, the shared skills it must build on, and its registration. Use whenever a skill is added or its shape changes; ai-prompt-writing owns how its rules are worded.
---

# Developing skills

A skill is one directory, `skills/<name>/`, holding `SKILL.md` and, when it does mechanical work, `scripts/` and `assets/`. Word its rules through `ai-prompt-writing`; this skill owns the shape around them.

## Layout

- **Name:** kebab-case, prefixed by its area — `agents-`, `ai-`, `dev-`, `docs-`, `git-`, `ui-`, `text-`, `ut-` — and identical to the frontmatter `name`.
- **Frontmatter:** `name` and `description`, plus `allowed-tools` when the skill restricts its tools. The description says what the skill does and when to use it, since that is what the tool matches on.
- **Scripts:** PowerShell 7, starting with `#Requires -Version 7`, non-interactive, exiting non-zero on failure. Each script with branching logic gets a `test-<script>.ps1` beside it that writes its fixtures under `.artifacts/` and prints one pass line. `tests/run-all.ps1` finds and runs every one.
- **Output:** a script's result is printed for the user. Write it in `agents-ui`'s safe Markdown (pipe tables, short status lines, a report's path) with progress noise kept off stdout, so the agent can relay it as `agents-ui` requires without reshaping it. SKILL.md says what the output shows and that the agent relays it.
- **Paths:** in SKILL.md commands, write the skill's own scripts as `<skill>/scripts/...` and another skill's folder as `<that-skill-name>`, such as `<git-commit>`, which is the form `AGENTS.md` defines. Inside a script, reach the skill's own files through `$PSScriptRoot`. Never use an absolute path, a path through this repository's layout such as `skills/<name>`, or a submodule folder name.
- **Self-contained:** everything a skill runs lives in `skills/<name>/`. No folder at the repository root or elsewhere holds code that skills share. Such a folder ties every skill to this repository's layout, so a skill installed or published on its own breaks.

## Dependencies between skills

Composing skills is intended. Coupling to another skill's internals is not.

- **Prefer the agent as the link.** SKILL.md names the other skill, and the agent runs that skill's documented command. No script holds the other skill's path.
- **Scripts call public entry points only, through a passed folder.** Skills need not be installed side by side, so a script never guesses another skill's location, whether through `$PSScriptRoot/../..`, a registry, or a fixed path. It takes the folder as a mandatory parameter named after the skill, such as `-GitCommitSkill`, and SKILL.md passes `<git-commit>` in the command. The script checks that the public script exists in that folder and throws naming the parameter when it does not. It never imports another skill's `.psm1` module. When a caller needs more than a public script offers, extend that script's parameters instead.
- **Vendor small helpers.** A few generic functions that two skills need are copied into each one, and each copy is owned by its skill and marked as a copy. Sharing them is not worth the coupling.
- **Declare and layer.** List every skill whose folder a command passes in the frontmatter as `metadata:` → `requires: <skill> <skill>`, one space-separated string, because the Agent Skills format allows only string metadata values. Dependencies point downward to foundation skills such as `git-commit`, `docs-html-report`, `ui-dark-cockpit`, `docs-md-writing`, `artifact-storage`, and `agents-ui`. Foundation skills depend on nothing, and no two skills depend on each other.

## Shared skills it must build on

A skill does not restate what one of these owns; it names the skill at the point of use.

| When the skill... | It uses |
| --- | --- |
| shows a table, asks, offers a choice, or asks to confirm | `agents-ui` — always, with no skill-specific question format |
| reports findings, checks, or risks | `ui-dark-cockpit` |
| writes a file that is not repository content | `artifact-storage` |
| writes an HTML page | `docs-html-report` |
| writes Markdown | `docs-md-writing` |
| commits | `git-commit` |

## Registration

Add the skill to the table in `AGENTS.md` and in `skills/README.md`, with the same one-line use, and update the root `README.md` where it describes what the skill changes. `agents-modify`'s `check-registration.ps1` fails when the folders, the two tables, or the declared dependencies disagree. A rename updates every reference in the repository in the same change; search for the old name until nothing is left. Checks and relinking belong to `agents-modify`, through which every change here lands.
