---
name: agents-dev-skills
description: Create, rename, or restructure a skill in this agents repository — its directory, frontmatter, scripts and their tests, the shared skills it must build on, and its registration. Use whenever a skill is added or its shape changes; ai-prompt-writing owns how its rules are worded.
---

# Developing skills

A skill is one directory, `skills/<name>/`, holding `SKILL.md` and, when it does mechanical work, `scripts/` and `assets/`. Word its rules through `ai-prompt-writing`; this skill owns the shape around them.

## Layout

- **Name:** kebab-case, prefixed by its area — `agents-`, `ai-`, `dev-`, `docs-`, `git-`, `ui-`, `text-`, `ut-` — and identical to the frontmatter `name`.
- **Frontmatter:** `name` and `description`, plus `allowed-tools` when the skill restricts its tools. The description says what the skill does and when to use it, since that is what the tool matches on.
- **Scripts:** PowerShell 7, starting with `#Requires -Version 7`, non-interactive, exiting non-zero on failure. Each script with branching logic gets a `test-<script>.ps1` beside it that writes its fixtures under `.artifacts/` and prints one pass line.
- **Paths:** refer to bundled files as `<skill>/scripts/...` and to other skills by name, never by an absolute path.

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

Add the skill to the table in `AGENTS.md` and in `skills/README.md`, with the same one-line use. A rename updates every reference in the repository in the same change; search for the old name until nothing is left. Checks and relinking belong to `agents-modify`, through which every change here lands.
