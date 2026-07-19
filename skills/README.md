# Skills

Reusable agent actions. Each skill contains a concise `SKILL.md`; deterministic
mechanical work may also use PowerShell 7 scripts under `scripts/`.

| Skill | When to use |
| --- | --- |
| [`workflow`](workflow/SKILL.md) | Enforce and persist Quick, Detailed, or Detailed Auto work. |
| [`install-powershell`](install-powershell/SKILL.md) | Bootstrap or verify PowerShell 7. |
| [`adr`](adr/SKILL.md) | Record an architectural decision. |
| [`adversarial-ut`](adversarial-ut/SKILL.md) | Build adversarial tests before fixing. |
| [`code-review`](code-review/SKILL.md) | Record structured JSON findings and render review Markdown. |
| [`debug`](debug/SKILL.md) | Diagnose a resistant failure. |
| [`design`](design/SKILL.md) | Structure a deeper design decision. |
| [`merge`](merge/SKILL.md) | Complete an approved Detailed merge. |
| [`retro`](retro/SKILL.md) | Review and improve the process. |

To add a skill, create `skills/<verb-led-name>/SKILL.md` with `name` and a
trigger-focused `description`. Add a PowerShell script only for repeated,
mechanical operations and ensure it exits non-zero on failure. Register the
skill in this table and in `../AGENTS.md`.
