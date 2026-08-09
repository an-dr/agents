# Skills

Reusable agent actions. Each skill contains a concise `SKILL.md`; deterministic mechanical work may also use PowerShell 7 scripts under `scripts/`.

| Skill | When to use |
| --- | --- |
| [`dev-workflow`](dev-workflow/SKILL.md) | Enforce and persist Quick, Detailed, or Detailed Auto work. |
| [`install-powershell`](install-powershell/SKILL.md) | Bootstrap or verify PowerShell 7. |
| [`agents-integration`](agents-integration/SKILL.md) | Onboard a host project onto this repo (submodule + `AGENTS.md`/`CLAUDE.md`). |
| [`agents-install`](agents-install/SKILL.md) | Install this clone globally for local AI tools, so no submodule is needed. |
| [`agents-modify`](agents-modify/SKILL.md) | Amend this repository's own instructions from wherever the need appeared. |
| [`ai-prompt-review`](ai-prompt-review/SKILL.md) | Review agent instructions for contradictions, weak rules, and wasted context. |
| [`docs-adr`](docs-adr/SKILL.md) | Record an architectural decision. |
| [`docs-md-writing`](docs-md-writing/SKILL.md) | Format any Markdown file and check it. |
| [`docs-readme`](docs-readme/SKILL.md) | Rewrite a README against the repository's own evidence. |
| [`ut-adversarial`](ut-adversarial/SKILL.md) | Build adversarial tests before fixing. |
| [`dev-code-review`](dev-code-review/SKILL.md) | Record structured JSON findings and render review Markdown. |
| [`dev-debug`](dev-debug/SKILL.md) | Diagnose a resistant failure. |
| [`dev-design`](dev-design/SKILL.md) | Structure a deeper design decision. |
| [`dev-summary`](dev-summary/SKILL.md) | Prepare the full-branch integration handoff. |
| [`dev-workflow-clean-branch`](dev-workflow-clean-branch/SKILL.md) | Remove workflow state from feature-branch history. |
| [`git-commit`](git-commit/SKILL.md) | Compose and record a commit in the unified message format. |
| [`git-commit-fix`](git-commit-fix/SKILL.md) | Rewrite existing commit messages to that format. |
| [`git-integrate`](git-integrate/SKILL.md) | Complete an approved integration in the mode the user chooses. |
| [`agents-retro`](agents-retro/SKILL.md) | Review and improve the process. |

Names carry a domain prefix — `agents-` for this repository's own installation and process, `ai-` for work on agent instructions in general, `dev-` for the development workflow, `git-` for repository history, `docs-` for documentation artifacts, `ut-` for tests. `install-powershell` is the one environment bootstrap and stays unprefixed.

To add a skill, create `skills/<prefix>-<action>/SKILL.md` with a matching `name` and a trigger-focused `description`. Add a PowerShell script only for repeated, mechanical operations and ensure it exits non-zero on failure. Register the skill in this table and in `../AGENTS.md`.
