---
name: convention-agent-skill
description: What a skill looks like in this repository — directory and name prefixes, frontmatter, kinds of skill, description pattern, title, section order, voice, commands, size, declared dependencies, and registration — so every skill reads alike. Use when creating, renaming, restructuring, writing, or reviewing any skill; check-registration.ps1 and check-skills.ps1 in this skill enforce it.
metadata:
  dependencies: concept-clean-dependencies convention-script
---

# Convention: agent skill

A reader or an agent that has seen one skill should find every other one in the same places. This convention owns the shape of a skill: where it lives, what it is called, what its text says and in what order, what it declares, and how it is registered. A skill is one directory, `skills/<name>/`, holding `SKILL.md` and, when it does mechanical work, `scripts/` and `assets/`. Scripts follow `convention-script`.

## Layout

- **Name:** kebab-case, prefixed by its area — `agents-`, `ai-`, `concept-`, `convention-`, `dev-`, `docs-`, `git-`, `text-`, `ut-` — and identical to the frontmatter `name`. The one environment-bootstrap skill stays unprefixed.
- **Frontmatter:** `name` and `description` first, then `allowed-tools` when the skill restricts its tools, then `metadata:` with `dependencies`.
- **Paths:** in SKILL.md commands, write the skill's own scripts as `<skill>/scripts/...` and another skill's folder as `<that-skill-name>`, which is the form `AGENTS.md` defines. Never use an absolute path, a path through this repository's layout such as `skills/<name>`, or a submodule folder name.
- **Self-contained:** everything a skill runs lives in `skills/<name>/`.

## Kinds of skill

| Kind | Holds | Contains |
| --- | --- | --- |
| Task | A procedure the agent runs | `SKILL.md`, scripts, assets |
| Concept | A reusable principle: what it requires, where its boundary is, how to recognise a violation | `SKILL.md` only |
| Convention | The format rules for an artifact: what a correct one looks like | `SKILL.md` and the scripts that check or generate what it describes |

A concept is read, not run: it has no scripts, calls no task skill, and is never passed as a folder. A convention reinforces its rules with scripts: a checker, a generator, or a test that fails when the rules are broken. Those scripts call no task skill, and task skills reach them like any public script, through a passed folder. Task skills apply a concept or convention by naming it at the point of use. Colours, glyphs, and other presentation details belong to an implementor, not to a concept.

## Description

- One to three sentences in the frontmatter `description`, on one line.
- A task skill opens with a verb saying what it does: `Review a diff for defects ...`. A concept or convention opens with what it defines: `The format of ...`.
- It ends with a trigger sentence beginning `Use `: `Use when ...`, `Use during ...`, or `Use to ...`. The tool matches on this sentence to load the skill, so it names the situations, not the skill's internals.
- It names no step of the procedure and no file the skill happens to contain.

## Title and opening

- One `#` heading, first in the body. Task skills use a short noun phrase: `# Commit`. Concepts use `# Concept: <name>` and conventions use `# Convention: <name>`.
- The opening paragraph, one to three sentences, says what the skill owns and what it leaves to others, naming each other skill it defers to. A reader can decide from it whether to keep reading.

## Sections

Sections are `##` headings in sentence case, named for what the reader does or finds there. Use these, in this order, omitting any that do not apply.

| Kind | Sections |
| --- | --- |
| Task | procedure sections named for their action (`## Select the diff`, `## Capture`), then `## Check` or `## Verify` when the skill verifies its work, then `## Output` for what it hands back, then `## Rules` for invariants, last |
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

Dependencies follow `concept-clean-dependencies`. Composing skills is intended; coupling to another skill's internals is not.

- **Prefer the agent as the link.** SKILL.md names the other skill, and the agent runs that skill's documented command. No script holds the other skill's path.
- **Declare every dependency.** The frontmatter lists every skill this skill names, as `metadata:` → `dependencies: <skill> <skill>`, one space-separated string, because the Agent Skills format allows only string metadata values. A command that passes another skill's folder names that skill, so it is declared too.
- **Mark stable skills.** `dependencies: PROHIBITED` marks a skill that must never name another skill, such as a concept or a leaf convention. `dependencies: none` marks a skill with no dependency today that may gain one.
- **Layer.** Dependencies point toward more stable skills: concepts, then conventions, then foundation services. A stable skill never names its consumers, and a cycle is broken as `concept-clean-dependencies` describes.

## Registration

Add the skill to the table in `AGENTS.md` and in `skills/README.md`, with the same one-line use, and update the root `README.md` where it describes what the skill changes. A rename updates every reference in the repository in the same change; search for the old name until nothing is left.

## Check

```powershell
pwsh <skill>/scripts/check-registration.ps1 [-Root <repository>] [-FailOnCycle]
pwsh <skill>/scripts/check-skills.ps1 [-Root <repository>]
```

`check-registration.ps1` fails when the folders, the two skill tables, or the frontmatter disagree: a skill that names an undeclared skill or declares one it never names, a `PROHIBITED` skill that names any other, a name that does not match its folder, or code outside `skills/`. It lists every dependency cycle with its path, and fails on a cycle only with `-FailOnCycle`.

`check-skills.ps1` reads every `SKILL.md` and reports a description that lacks a trigger sentence, a title that does not match the skill's kind, a missing or misplaced section from the table above, and a skill over the size limit.

Both exit non-zero on a problem. Each has a `test-` script in the same folder that breaks a copy of the repository one way at a time to prove every report.
