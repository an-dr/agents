# Skills

Reusable agent actions. Each skill contains a concise `SKILL.md`; deterministic mechanical work may also use PowerShell 7 scripts under `scripts/`.

| Skill | When to use |
| --- | --- |
| [`dev-workflow`](dev-workflow/SKILL.md) | Enforce and persist gated Quick, Detailed, or Detailed Auto work; Direct needs no controller. |
| [`dev-build`](dev-build/SKILL.md) | Implement code within the selected workflow and repository conventions. |
| [`dev-testing`](dev-testing/SKILL.md) | Verify changed code and report meaningful test coverage. |
| [`docs-writing`](docs-writing/SKILL.md) | Write human-facing documentation and check its claims. |
| [`ai-prompt-writing`](ai-prompt-writing/SKILL.md) | Create or change agent-loaded instructions. |
| [`install-powershell`](install-powershell/SKILL.md) | Bootstrap or verify PowerShell 7. |
| [`agents-install`](agents-install/SKILL.md) | Install this clone globally for local AI tools, so no submodule is needed. |
| [`agents-health-check`](agents-health-check/SKILL.md) | Diagnose why a tool is not picking up or following the workflow. |
| [`agents-modify`](agents-modify/SKILL.md) | Amend this repository's own instructions from wherever the need appeared. |
| [`agents-dev-skills`](agents-dev-skills/SKILL.md) | Create, rename, or restructure a skill: layout, scripts, shared skills, and registration. |
| [`ai-prompt-review`](ai-prompt-review/SKILL.md) | Review agent instructions for contradictions, weak rules, and wasted context. |
| [`ui-dark-cockpit`](ui-dark-cockpit/SKILL.md) | Present findings with normal results unlit and only problems visible, red for critical alone. |
| [`agents-ui`](agents-ui/SKILL.md) | Ask questions and confirmations through the host's UI, fall back to text, and render tables that work everywhere. |
| [`text-claim-audit`](text-claim-audit/SKILL.md) | Check a report or analysis against its sources and separate facts from inference and opinion. |
| [`docs-adr`](docs-adr/SKILL.md) | Record an architectural decision. |
| [`docs-md-writing`](docs-md-writing/SKILL.md) | Format any Markdown file and check it. |
| [`docs-html-report`](docs-html-report/SKILL.md) | Build a self-contained HTML report page with offline-rendered Mermaid diagrams. |
| [`artifact-storage`](artifact-storage/SKILL.md) | Place a generated artifact and create its per-run directory. |
| [`docs-readme`](docs-readme/SKILL.md) | Rewrite a README against the repository's own evidence. |
| [`docs-screenshot`](docs-screenshot/SKILL.md) | Capture a website, GUI application, or game as documentation media. |
| [`docs-gif`](docs-gif/SKILL.md) | Record an animated GIF of a website, application, or game, only on request. |
| [`ut-adversarial`](ut-adversarial/SKILL.md) | Build adversarial tests before fixing. |
| [`dev-code-review`](dev-code-review/SKILL.md) | Record structured JSON findings and render an HTML review report. |
| [`dev-project-overview`](dev-project-overview/SKILL.md) | Explain an unfamiliar repository in one HTML page, with C4 diagrams, doc-versus-code drift, and its real problems. |
| [`dev-debug`](dev-debug/SKILL.md) | Diagnose a resistant failure. |
| [`dev-design`](dev-design/SKILL.md) | Structure a deeper design decision. |
| [`dev-summary`](dev-summary/SKILL.md) | Prepare the full-branch integration handoff. |
| [`dev-change-report`](dev-change-report/SKILL.md) | Explain a finished change in one HTML page: new and upgraded blocks, rendered dependency graphs, decisions, and verification. |
| [`dev-workflow-clean-branch`](dev-workflow-clean-branch/SKILL.md) | Remove workflow state from feature-branch history. |
| [`git-commit`](git-commit/SKILL.md) | Compose and record a commit in the unified message format. |
| [`git-commit-fix`](git-commit-fix/SKILL.md) | Rewrite existing commit messages to that format. |
| [`git-integrate`](git-integrate/SKILL.md) | Complete an approved integration in the mode the user chooses. |
| [`agents-retro`](agents-retro/SKILL.md) | Review and improve the process. |
| [`an-dr-tools-update`](an-dr-tools-update/SKILL.md) | Register the user's local tool repositories and pull, rebuild, and reinstall them. |

Names carry a domain prefix — `agents-` for this repository's own installation and process, `ai-` for work on agent instructions in general, `dev-` for the development workflow, `git-` for repository history, `docs-` for documentation artifacts, `text-` for checking prose the user brings in, `ui-` for how outputs present what they found, `ut-` for tests, `artifact-` for where generated artifacts live, `an-dr-` for the user's personal toolchain. `install-powershell` is the one environment bootstrap and stays unprefixed.

To add a skill, create `skills/<prefix>-<action>/SKILL.md` with a matching `name` and a trigger-focused `description`. Add a PowerShell script only for repeated, mechanical operations and ensure it exits non-zero on failure. Register the skill in this table and in `../AGENTS.md`.
