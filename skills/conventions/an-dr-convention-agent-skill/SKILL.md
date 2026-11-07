---
name: an-dr-convention-agent-skill
description: The shape of a skill in any repository that uses it — Agent Skills format with the an-dr extensions, types, layout, text, size and reference files, dependencies, and registration. Use when creating, renaming, restructuring, writing, or reviewing any skill.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.3.0"
  an-dr.type: convention
  an-dr.dependencies: an-dr-concept-clean-dependencies an-dr-convention-script an-dr-convention-agent-skill-testing
---

# Convention: agent skill

A reader or an agent that has seen one skill finds every other one in the same places. This convention describes the shape of a skill: the standard format it builds on, the extensions it adds, where a skill lives, what its text says and in what order, and how it is registered. Scripts are described by `an-dr-convention-script`; test packaging by `an-dr-convention-agent-skill-testing`.

## Types

| Type       | Holds                                                                              | Agent uses it by                                   | Contains                                                     |
| ---------- | ---------------------------------------------------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------ |
| Action     | A procedure that produces a result                                                 | running it                                         | `SKILL.md`, references, scripts, assets, tests               |
| Concept    | A principle: what it requires, where its boundary is, how to recognise a violation | reading it when its subject is in play             | `SKILL.md` and evals; no production scripts                  |
| Convention | The format rules for an artifact: what a correct one looks like                    | reading it when writing or reviewing that artifact | `SKILL.md`, references, tests, and the scripts that check it |

- **Concepts and conventions only describe.** They state what a principle requires or what a correct artifact looks like, in declarative sentences, and hold no steps, no instructions to the agent, and no commands to run. When to apply one, what to run, and what to tell the user are always the responsibility of the action that uses it.
- **A concept** has no production scripts and names no action; its tests assess application of the principle. Colours, glyphs, and other presentation details belong to an implementor, not to a concept.
- **A convention** may ship scripts that check or generate its artifact. Its text says what each script verifies; an action runs them, reaching them through a passed folder, and the scripts call no action.

## Reference files of this convention

- [references/placement.md](references/placement.md): folders, names, paths, and registration.
- [references/frontmatter.md](references/frontmatter.md): the format, the metadata extensions, and the description.
- [references/body.md](references/body.md): the title, the section order for each type, voice, and commands.
- [references/dependencies.md](references/dependencies.md): dependencies, which follow `an-dr-concept-clean-dependencies`.

## Size and references

An agent reads a skill in three layers: the description in every session, `SKILL.md` when it uses the skill, and a reference file only when it needs that file. Each fact sits in the cheapest layer that still reaches the agent when it is needed. Sizes are approximate tokens, characters divided by four.

- **Core.** `SKILL.md` holds what every use needs and a pointer to each reference file. It is at most 1,500 tokens, ideally about 1,000.
- **References.** Material that only some uses need, such as one mode, one case, an output format, a long table, or a host-specific procedure, is a file `references/<topic>.md`. Each file stands alone, has no frontmatter, and is under 1,500 tokens.
- **Pointers.** In an action, a pointer is an instruction at the step that needs the file, with the path as a Markdown link, such as "Before asking for the mode, read references/modes.md"; a list of links at the end gets skipped. In a concept or convention, a pointer is an index entry saying what the file describes.
- **Private.** A reference file belongs to its skill. Another skill names the skill, never its reference files.
- **Merging.** Two actions that serve one task are one action with a reference file per branch. A concept or convention is never merged into another skill; other skills read it by name.

## Check

- `scripts/check-registration.ps1` verifies placement, registration, types against folders, and declared dependencies, and lists dependency cycles, which fail with `-FailOnCycle`; `-RequireTests` requires `evals/` in every skill.
- `scripts/check-skills.ps1` verifies the frontmatter, description, title, section order, and reference links, and warns on size and on a command block in a concept or convention.
- `scripts/check-skills-ref.ps1` verifies the format through `skills-ref validate`. Without `skills-ref` it prints the install command and exits 0; with `-Require` or in CI it exits 1.

Each takes `-Root <repository>`, prints what it found, and exits non-zero on a problem. Their regression tests are in `scripts/tests/`.
