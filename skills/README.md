# Skills

Reusable agent actions. Each skill is a directory:

```text
skills/<name>/
├── SKILL.md    # frontmatter (name, description, allowed-tools) + how to invoke
└── scripts/    # .sh for Linux/macOS, .ps1 for Windows — only for mechanical steps
```

Agents check this directory before starting any phase (see `../AGENTS.md`) and
follow a skill's `SKILL.md` instead of improvising the steps. `scripts/`
exists only where the steps are mechanical; judgment-only skills are
`SKILL.md` alone.

| Skill | When to use |
| ----- | ----------- |
| [`adr`](adr/SKILL.md) | DESIGN — record a settled architectural decision as the next-numbered ADR |
| [`adversarial-ut`](adversarial-ut/SKILL.md) | Start of a debug/cleanup iteration — build a bug-finding test suite before fixing anything |
| [`code-review`](code-review/SKILL.md) | VERIFY (increment diff) and MR (full branch diff) — review for defects and rule violations |
| [`merge`](merge/SKILL.md) | MERGE phase — rebase, squash, fast-forward the default branch, delete the feature branch |

## Adding a skill

1. Create `skills/<name>/SKILL.md` with frontmatter — `name` matching the
   directory, `description` stating what it does *and* when to use it,
   `allowed-tools` if restricted — and a usage section.
2. Scripts are optional: add them when the steps are mechanical enough to
   script, always in both `.sh` and `.ps1` variants; scripts exit non-zero
   on failure.
3. Register the skill in the tables here and in `../AGENTS.md`.
