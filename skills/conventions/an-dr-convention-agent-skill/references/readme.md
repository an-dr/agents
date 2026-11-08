# Skill README

`SKILL.md` instructs the agent; `README.md` beside it explains the skill to a person. Every skill has one. Agents do not load it, so it costs no context and may take the room a person needs.

## Reader and purpose

- The reader is a user of the repository deciding whether to rely on the skill, or trying to understand what the agent just did with it.
- It answers: what the skill is for, when it runs, how it works, what it produces, and what the person decides along the way.
- It describes behaviour, not instructions: no steps addressed to the agent, no duplicated rule lists. A rule's wording lives in `SKILL.md`; the README explains its effect and why it exists.

## Sections, in order

1. `# <skill-name>` and one sentence on what it is for.
2. **When it runs** — the triggers in plain words: which flow, phase, or request brings it in.
3. **How it works** — the procedure or the principle as a person sees it. A diagram where the skill has phases, branches, actors, or a lifecycle (Mermaid `flowchart`, `sequenceDiagram`, or `stateDiagram-v2`); prose alone for a skill that is one step or one rule.
4. **What you get** — outputs, files, reports, or the shape of a correct artifact.
5. **What you decide** — the questions and approvals that belong to the person; omit for a skill that asks nothing.
6. **Related skills** — the skills it works with, linked to their READMEs.

## Form

- Markdown under `an-dr-convention-markdown`; Mermaid in fenced `mermaid` blocks, which GitHub renders.
- About one screen to three screens; a diagram replaces prose it shows, never repeats it.
- No frontmatter. The skill's `references/` stay private to `SKILL.md`; the README links only to other skills' READMEs and to repository documents.
