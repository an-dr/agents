---
name: an-dr-convention-agent-skill
description: What a skill looks like in any repository that uses it — the Agent Skills format and the an-dr extensions on top of it — category folders, action, concept, and convention types, declared dependencies, description pattern, title, section order, voice, size, and registration. Use when creating, renaming, restructuring, writing, or reviewing any skill; the check scripts in this skill enforce it.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: convention
  an-dr.dependencies: an-dr-concept-clean-dependencies an-dr-convention-script
---

# Convention: agent skill

A reader or an agent that has seen one skill should find every other one in the same places. This convention owns the shape of a skill: the standard format it builds on, the extensions it adds, where a skill lives, what its text says and in what order, and how it is registered. Scripts follow `an-dr-convention-script`.

## The format and its extensions

Every skill is valid [Agent Skills](https://agentskills.io/specification) format, so any tool that reads it can load it: a folder `<name>/` holding `SKILL.md`, whose frontmatter has only `name`, `description`, `license`, `compatibility`, `metadata`, and `allowed-tools`. `license` names the licence, `allowed-tools` is one space-separated string, and `metadata` holds only string values.

The extensions live in `metadata`. `author` and `version` are plain keys, and the keys that carry meaning for this convention use the `an-dr.` prefix that keeps them clear of other tools' keys:

| Key | Value |
| --- | --- |
| `author` | who wrote the skill |
| `version` | the skill's version, a quoted semantic version |
| `an-dr.type` | `action`, `concept`, or `convention` |
| `an-dr.dependencies` | the skills this skill names, space-separated, or `none`, or `PROHIBITED` |

The extensions are conventions of the project, not of the format. A tool that ignores them still loads every skill; the rule for passive skills below is also stated in `AGENTS.md`, which every tool reads.

## Types

| Type | Holds | Agent uses it by | Contains |
| --- | --- | --- | --- |
| Action | A procedure that produces a result | running it | `SKILL.md`, scripts, assets |
| Concept | A principle: what it requires, where its boundary is, how to recognise a violation | reading it when its subject is in play | `SKILL.md` only |
| Convention | The format rules for an artifact: what a correct one looks like | reading it when writing or reviewing that artifact | `SKILL.md` and the scripts that check or generate it |

Concepts and conventions are passive: the agent reads them, never runs them as a procedure. A concept has no scripts and calls no action. A convention reinforces its rules with scripts that call no action, and actions reach them like any public script, through a passed folder. Colours, glyphs, and other presentation details belong to an implementor, not to a concept.

## Layout

- **Folders:** a skill is `skills/<category>/<name>/`. `actions/`, `concepts/`, and `conventions/` hold general skills of the matching type, and the folder and `an-dr.type` agree. A folder whose name starts with an underscore, such as `_repository/`, holds skills that exist for the repository itself, of any type.
- **Name:** kebab-case, identical to the folder and the frontmatter `name`. A concept's name contains `concept-` and a convention's contains `convention-`, so the type shows in a tool's flat skill list. A project may add a namespace prefix and a naming scheme for its actions. Names are unique across all folders, because tools install skills side by side.
- **Frontmatter order:** `name`, `description`, `license`, `allowed-tools` when the skill restricts its tools, then `metadata`.
- **Paths:** in SKILL.md commands, write the skill's own scripts as `<skill>/scripts/...` and another skill's folder as `<that-skill-name>`, which is the form `AGENTS.md` defines. Never use an absolute path, a path through this repository's layout, or a submodule folder name.
- **Self-contained:** everything a skill runs lives in its own folder.

## Description

- One to three sentences in the frontmatter `description`, on one line.
- An action opens with a verb saying what it does: `Review a diff for defects ...`. A concept or convention opens with what it defines: `The format of ...`.
- It ends with a trigger sentence beginning `Use `: `Use when ...`, `Use during ...`, or `Use to ...`. The tool matches on this sentence to load the skill, so it names the situations, not the skill's internals.
- It names no step of the procedure and no file the skill happens to contain.

## Title and opening

- One `#` heading, first in the body. Actions use a short noun phrase: `# Commit`. Concepts use `# Concept: <name>` and conventions use `# Convention: <name>`.
- The opening paragraph, one to three sentences, says what the skill owns and what it leaves to others, naming each other skill it defers to. A reader can decide from it whether to keep reading.

## Sections

Sections are `##` headings in sentence case, named for what the reader does or finds there. Use these, in this order, omitting any that do not apply.

| Kind | Sections |
| --- | --- |
| Action | procedure sections named for their action (`## Select the diff`, `## Capture`), then `## Check` or `## Verify` when the skill verifies its work, then `## Output` for what it hands back, then `## Rules` for invariants, last |
| Concept | the principle's sections, then `## Violations`; an optional review procedure may follow |
| Convention | the rule sections, then `## Check` when a script enforces them, then `## Examples`, last |

- A rule that applies everywhere in the skill goes in `## Rules`; a rule that applies to one step stays beside that step.
- Reference material that only a branch of the skill needs is a table or a section at the end of its group, not a preamble.

## Voice

- Write imperative, present tense, one observable rule per bullet. State what to do; add a reason only where the rule would otherwise seem arbitrary.
- Describe the skill as it works now. History, comparisons with an older design, and "no longer" belong in commit messages.
- Lead a list of parallel rules with a bold phrase naming the rule: `- **Trace.** A conclusion names its evidence.`
- Refer to another skill by its exact name in backticks, and keep one owner for each fact: name the owner instead of restating its rule.

## Commands

- Show each command in a fenced `powershell` block, with the skill's own scripts written `<skill>/scripts/<name>.ps1` and another skill's folder as `<that-skill-name>`.
- Follow the block with what it prints or returns, which exit codes mean what, and that the agent relays the result to the user.
- Put a deterministic check in a script, and say in one sentence what it checks. Do not describe it in prose that the script already enforces.

## Size

A skill past about 150 lines is two skills, or it hides logic that belongs in a script. Split it, or move the mechanical part out.

## Dependencies

Dependencies follow `an-dr-concept-clean-dependencies`. Composing skills is intended; coupling to another skill's internals is not.

- **Prefer the agent as the link.** SKILL.md names the other skill, and the agent runs that skill's documented command. No script holds the other skill's path.
- **Declare every dependency.** `an-dr.dependencies` lists every skill this skill names, passed folder or not.
- **Mark stable skills.** `PROHIBITED` marks a skill that must never name another skill, such as a concept or a leaf convention. `none` marks a skill with no dependency today that may gain one.
- **Layer.** Dependencies point toward more stable skills: concepts, then conventions, then foundation services. A stable skill never names its consumers.
- **Keep the repository's own skills apart.** A skill outside the underscore folders never depends on one inside them, so every general skill works without the repository's own tooling.

## Registration

Add the skill to the table in `skills/README.md` with a one-line use, and update the root `README.md` where it describes what the skill changes. A rename updates every reference in the repository in the same change; search for the old name until nothing is left.

## Check

```powershell
pwsh <skill>/scripts/check-registration.ps1 [-Root <repository>] [-FailOnCycle]
pwsh <skill>/scripts/check-skills.ps1 [-Root <repository>]
pwsh <skill>/scripts/check-skills-ref.ps1 [-Root <repository>] [-Require]
```

`check-registration.ps1` fails on a misplaced or unregistered skill, a type that disagrees with its folder, a concept or convention whose name lacks its type, a concept that holds more than `SKILL.md`, a skill that names an undeclared skill or declares one it never names, a `PROHIBITED` skill that names any other, and a general skill that depends on one in an underscore folder. It lists every dependency cycle with its path, and fails on a cycle with `-FailOnCycle`.

`check-skills.ps1` fails on frontmatter outside the Agent Skills format, a missing licence, author, version, or extension, a comma-separated `allowed-tools`, a description without a trigger sentence, a title or section order that does not match the type, and a skill over the size limit.

`check-skills-ref.ps1` runs `skills-ref validate`, the format's reference validator, on every skill. When `skills-ref` is missing it prints the install command and exits 0, and exits 1 with `-Require` or in CI. Installing it is the user's decision.

All three exit non-zero on a problem. Each has a `test-` script in the same folder that breaks a copy of the repository one way at a time to prove every report.
