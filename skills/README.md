# Skills

Scripted, reusable agent actions. Each skill is a directory:

```text
skills/<name>/
├── SKILL.md    # frontmatter (name, description, allowed-tools) + how to invoke
└── scripts/    # .sh for Linux/macOS, .ps1 for Windows — both always provided
```

Agents check this directory before starting any phase (see `../AGENTS.md`) and run
a skill's scripts instead of improvising the steps.

| Skill | When to use |
| ----- | ----------- |
| [`merge`](merge/SKILL.md) | MERGE phase — rebase, squash, fast-forward the default branch, delete the feature branch |

## Adding a skill

1. Create `skills/<name>/SKILL.md` with frontmatter (`name`, `description`,
   `allowed-tools`) and both an agent (non-interactive) and a human
   (interactive) usage section.
2. Provide every script in both `.sh` and `.ps1` variants; scripts exit non-zero
   on failure.
3. Register the skill in the tables here and in `../AGENTS.md`.
