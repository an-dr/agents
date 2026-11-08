---
name: an-dr-convention-agent-skill
description: The shape of a skill in any repository that uses it — Agent Skills format with the an-dr extensions, types, layout, text, size and reference files, dependencies, and registration. Use when creating, renaming, restructuring, writing, or reviewing any skill.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.5.0"
  an-dr.type: convention
  an-dr.dependencies: an-dr-concept-clean-dependencies an-dr-convention-script an-dr-convention-agent-skill-testing an-dr-convention-markdown
---

# Convention: agent skill

Defers: scripts to `an-dr-convention-script`, test packaging to `an-dr-convention-agent-skill-testing`.

## Types

| Type       | Holds                                                                              | Agent uses it by                                   | Contains                                                      |
| ---------- | ---------------------------------------------------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------- |
| Action     | A procedure that produces a result                                                 | running it                                         | `SKILL.md`, `README.md`, references, scripts, assets, tests   |
| Concept    | A principle: what it requires, where its boundary is, how to recognise a violation | reading it when its subject is in play             | `SKILL.md`, `README.md`, and evals; no production scripts     |
| Convention | The format rules for an artifact: what a correct one looks like                    | reading it when writing or reviewing that artifact | `SKILL.md`, `README.md`, references, tests, and check scripts |

- Concepts and conventions only describe: declarative statements, no steps, no instructions to the agent, no commands to run; when to apply one, what to run, and what to tell the user belong to the action that uses it.
- A concept has no production scripts and names no action; its tests assess application of the principle; presentation details such as colours and glyphs belong to an implementor.
- A convention may ship scripts that check whether an artifact follows the convention, or that generate the artifact; its text says what each script verifies, an action runs them through a passed folder, and the scripts call no action.

## Reference files of this convention

- [references/placement.md](references/placement.md): folders, names, paths, and registration.
- [references/frontmatter.md](references/frontmatter.md): the format, the metadata extensions, and the description.
- [references/body.md](references/body.md): the title, the section order for each type, voice, and commands.
- [references/size.md](references/size.md): description and body wording, format by content, scripts, progressive disclosure, and the final pass.
- [references/dependencies.md](references/dependencies.md): dependencies, which follow `an-dr-concept-clean-dependencies`.
- [references/readme.md](references/readme.md): the person-facing `README.md` every skill carries beside `SKILL.md`.

## Size and references

Layers: description in every session → `SKILL.md` on use → reference file on need. Each fact sits in the cheapest layer that still reaches the agent. Tokens ≈ characters / 4.

- Core: `SKILL.md` holds what every use needs and a pointer to each reference file; at most 1,500 tokens, ideally about 1,000, well under 200 lines.
- References: material only some uses need (one mode, one case, an output format, a long table, a host-specific procedure) is `references/<topic>.md`; each stands alone, has no frontmatter, and is under 1,500 tokens.
- Pointers: in an action, an instruction at the step that needs the file, path as a Markdown link ("Before asking for the mode, read references/modes.md"), never a link list at the end; in a concept or convention, an index entry saying what the file describes.
- Private: a reference file belongs to its skill; another skill names the skill, never its reference files.
- Merging: two actions serving one task are one action with a reference file per branch; a concept or convention is never merged into another skill.

## Check

- `scripts/check-registration.ps1` verifies placement, registration, types against folders, and declared dependencies, and lists dependency cycles, which fail with `-FailOnCycle`; `-RequireTests` requires `evals/` in every skill.
- `scripts/check-skills.ps1` verifies the frontmatter, description, title, section order, reference links, and that `README.md` exists, and warns on size, on the size.md wording rules it can detect (description sentences, body lines, intro paragraph, bold rule names), and on a command block in a concept or convention.
- `scripts/check-skills-ref.ps1` verifies the format through `skills-ref validate`. Without `skills-ref` it prints the install command and exits 0; with `-Require` or in CI it exits 1.

Each takes `-Root <repository>`, prints what it found, and exits non-zero on a problem. Their regression tests are in `scripts/tests/`.
