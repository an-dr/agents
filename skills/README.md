# Skills

Reusable agent actions. Each skill contains a concise `SKILL.md`; deterministic mechanical work may also use PowerShell 7 scripts under `scripts/`.

| Skill | When to use |
| --- | --- |
| [`dev-workflow`](dev-workflow/SKILL.md) | Start, resume, advance, approve, reshape, or finish a workflow. |
| [`dev-build`](dev-build/SKILL.md) | Implement code within the selected workflow and repository conventions. |
| [`dev-testing`](dev-testing/SKILL.md) | Verify changed code and report meaningful test coverage. |
| [`docs-writing`](docs-writing/SKILL.md) | Write human-facing documentation and check its claims. |
| [`ai-prompt-writing`](ai-prompt-writing/SKILL.md) | Create or change agent-loaded instructions. |
| [`install-powershell`](install-powershell/SKILL.md) | Install or verify PowerShell 7 before running scripts. |
| [`agents-install`](agents-install/SKILL.md) | Install this clone globally for local AI tools instead of per repository. |
| [`agents-health-check`](agents-health-check/SKILL.md) | Diagnose why a tool is not picking up or following this workflow. |
| [`agents-modify`](agents-modify/SKILL.md) | Change this repository's own instructions and land them after approval. |
| [`agents-dev-skills`](agents-dev-skills/SKILL.md) | Create, rename, or restructure a skill: layout, scripts, shared skills, and registration. |
| [`ai-prompt-review`](ai-prompt-review/SKILL.md) | Review agent instructions for contradictions, weak rules, and wasted context. |
| [`ui-dark-cockpit`](ui-dark-cockpit/SKILL.md) | Present findings with normal results unlit and only problems visible, red for critical alone. |
| [`agents-ui`](agents-ui/SKILL.md) | Ask questions and confirmations through the host's UI, fall back to text, and render tables that work everywhere. |
| [`text-claim-audit`](text-claim-audit/SKILL.md) | Check a report or analysis against its sources and separate facts from inference and opinion. |
| [`docs-adr`](docs-adr/SKILL.md) | Record a settled architectural decision. |
| [`docs-md-writing`](docs-md-writing/SKILL.md) | Format conventions and a checker for any Markdown file. |
| [`docs-html-report`](docs-html-report/SKILL.md) | Build a self-contained HTML report page with rendered Mermaid diagrams. |
| [`artifact-storage`](artifact-storage/SKILL.md) | Place a generated artifact and create its run directory. |
| [`docs-readme`](docs-readme/SKILL.md) | Rewrite a README from what the repository actually contains. |
| [`docs-screenshot`](docs-screenshot/SKILL.md) | Capture a website, GUI application, or game as documentation media. |
| [`docs-gif`](docs-gif/SKILL.md) | Record an animated GIF of a website, application, or game, only on request. |
| [`ut-adversarial`](ut-adversarial/SKILL.md) | Build bug-finding tests before a debug or cleanup fix. |
| [`dev-analysis-deslop`](dev-analysis-deslop/SKILL.md) | Analyse code and docs for illogical or questionable artifacts, with prioritized findings and proposed changes in HTML. |
| [`dev-analysis-review`](dev-analysis-review/SKILL.md) | Review an increment or full branch diff. |
| [`dev-project-overview`](dev-project-overview/SKILL.md) | Explain an unfamiliar repository in one HTML page, code first. |
| [`dev-debug`](dev-debug/SKILL.md) | Reproduce and instrument a resistant failure. |
| [`dev-design`](dev-design/SKILL.md) | Explore a deeper decision with options, steelman, and pre-mortem. |
| [`dev-analysis-summary`](dev-analysis-summary/SKILL.md) | Review the full branch and prepare the integration handoff. |
| [`dev-analysis-change`](dev-analysis-change/SKILL.md) | Explain a finished change in one HTML page, with diagrams instead of code. |
| [`dev-workflow-clean-branch`](dev-workflow-clean-branch/SKILL.md) | Remove `.progress/` from every feature-branch commit. |
| [`git-commit`](git-commit/SKILL.md) | Compose and record a commit in the unified message format. |
| [`git-commit-fix`](git-commit-fix/SKILL.md) | Rewrite existing commit messages to that format. |
| [`git-integrate`](git-integrate/SKILL.md) | Integrate an approved branch in the mode the user chooses. |
| [`agents-retro`](agents-retro/SKILL.md) | Propose process improvements after integration or on request. |

Names carry a domain prefix — `agents-` for this repository's own installation and process, `ai-` for work on agent instructions in general, `dev-` for the development workflow, `git-` for repository history, `docs-` for documentation artifacts, `text-` for checking prose the user brings in, `ui-` for how outputs present what they found, `ut-` for tests, `artifact-` for where generated artifacts live. `install-powershell` is the one environment bootstrap and stays unprefixed.

To add a skill, create `skills/<prefix>-<action>/SKILL.md` with a matching `name` and a trigger-focused `description`. Add a PowerShell script only for repeated, mechanical operations and ensure it exits non-zero on failure. Register the skill in this table and in `../AGENTS.md`.
