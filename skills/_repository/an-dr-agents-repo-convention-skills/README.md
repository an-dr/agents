# an-dr-agents-repo-convention-skills

This repository's naming, metadata, and test rules for its own skills, on top of the general skill convention: the `an-dr-` namespace, groups, verbs, and type words.

## When it runs

A convention is read, never run. It applies when naming, renaming, or reviewing a skill here; `check-names.ps1` enforces the names.

## How it works

Every name starts with `an-dr-`, because tools install skills side by side in one folder, and uses hyphens only.

| Skill                      | Name after `an-dr-`           | Example                        |
| -------------------------- | ----------------------------- | ------------------------------ |
| Action                     | `<group>-<verb>[-<noun>]`     | `an-dr-dev-test`               |
| Concept                    | `concept-<name>`              | `an-dr-concept-ai-slop`        |
| Convention                 | `convention-<name>`           | `an-dr-convention-markdown`    |
| Action on this repository  | `agents-repo-<verb>[-<noun>]` | `an-dr-agents-repo-install`    |
| Action on the agents' work | `agents-<verb>[-<noun>]`      | `an-dr-agents-analyze-session` |

Groups (`ai`, `dev`, `architecture`, `project`, `text`, `files`, `git`, `env`, …) say what area an action works in, and the verb comes from a fixed table with distinct meanings — `analyze` changes nothing, `build` assembles a derived artefact, `write` produces content. A new verb is added to the table before use.

## What you get

Names that tell you, in a flat skill list, what a skill is and what it does.

## Related skills

- [an-dr-convention-agent-skill](../../conventions/an-dr-convention-agent-skill/README.md) — the general shape.
