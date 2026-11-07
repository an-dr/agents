# Frontmatter and description

Every skill is valid [Agent Skills](https://agentskills.io/specification) format, so any tool that reads it can load it: a folder `<name>/` holding `SKILL.md`, whose frontmatter has only `name`, `description`, `license`, `compatibility`, `metadata`, and `allowed-tools`. `license` names the licence, `allowed-tools` is one space-separated string, and `metadata` holds only string values.

## Order

`name`, `description`, `license`, `allowed-tools` when the skill restricts its tools, then `metadata`.

## Extensions

The extensions live in `metadata`. `author` and `version` are plain keys, and the keys that carry meaning for this convention use the `an-dr.` prefix that keeps them clear of other tools' keys:

| Key                  | Value                                                                    |
| -------------------- | ------------------------------------------------------------------------ |
| `author`             | who wrote the skill                                                      |
| `version`            | the skill's version, a quoted semantic version                           |
| `an-dr.type`         | `action`, `concept`, or `convention`                                     |
| `an-dr.dependencies` | the skills this skill names, space-separated, or `none`, or `PROHIBITED` |

The extensions are conventions of the project, not of the format. A tool that ignores them still loads every skill; the rule for passive skills is also stated in `AGENTS.md`, which every tool reads.

## Description

- One to three sentences in the frontmatter `description`, on one line, at most 300 characters, because every session loads it.
- An action opens with a verb saying what it does: `Review a diff for defects ...`. A concept or convention opens with what it defines: `The format of ...`.
- It ends with a trigger sentence beginning `Use `: `Use when ...`, `Use during ...`, or `Use to ...`. The tool matches on this sentence to load the skill, so it names the situations, not the skill's internals.
- It names no step of the procedure and no file the skill happens to contain.
