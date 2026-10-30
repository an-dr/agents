# Skills

Reusable skills in the [Agent Skills](https://agentskills.io/specification) format. Each skill is a folder with a concise `SKILL.md`; deterministic mechanical work may also use PowerShell 7 scripts under `scripts/`. A skill sits one level below its category folder, and the category says how the agent uses it.

## Actions

Procedures the agent runs. They produce a result, use scripts where the work is mechanical, and apply the concepts and conventions below.

| Skill | When to use |
| --- | --- |
| [`an-dr-ai-review-instruction`](actions/an-dr-ai-review-instruction/SKILL.md) | Review agent instructions for contradictions, weak rules, and wasted context. |
| [`an-dr-ai-send-message`](actions/an-dr-ai-send-message/SKILL.md) | Ask questions and confirmations through the host's UI, fall back to text, and render tables that work everywhere. |
| [`an-dr-ai-write-instruction`](actions/an-dr-ai-write-instruction/SKILL.md) | Create or change agent-loaded instructions. |
| [`an-dr-architecture-fix-dependencies`](actions/an-dr-architecture-fix-dependencies/SKILL.md) | Remove needless dependencies and break cycles by moving shared parts into common components. |
| [`an-dr-dev-analyze-changes`](actions/an-dr-dev-analyze-changes/SKILL.md) | Explain a finished change in one HTML page, and prepare the full-branch integration handoff. |
| [`an-dr-dev-analyze-slop`](actions/an-dr-dev-analyze-slop/SKILL.md) | Analyse code and docs for illogical or questionable artifacts, with prioritized findings and proposed changes in HTML. |
| [`an-dr-dev-debug`](actions/an-dr-dev-debug/SKILL.md) | Reproduce and instrument a resistant failure. |
| [`an-dr-dev-design`](actions/an-dr-dev-design/SKILL.md) | Explore a deeper decision with options, steelman, and pre-mortem. |
| [`an-dr-dev-follow-workflow`](actions/an-dr-dev-follow-workflow/SKILL.md) | Start, resume, advance, approve, reshape, or finish a workflow. |
| [`an-dr-dev-implement-adversarial-ut`](actions/an-dr-dev-implement-adversarial-ut/SKILL.md) | Build bug-finding tests before a debug or cleanup fix. |
| [`an-dr-dev-implement-code`](actions/an-dr-dev-implement-code/SKILL.md) | Implement code within the selected workflow and repository conventions. |
| [`an-dr-dev-integrate`](actions/an-dr-dev-integrate/SKILL.md) | Integrate an approved branch in the mode the user chooses. |
| [`an-dr-dev-review`](actions/an-dr-dev-review/SKILL.md) | Review an increment or full branch diff. |
| [`an-dr-dev-test`](actions/an-dr-dev-test/SKILL.md) | Verify changed code and report meaningful test coverage. |
| [`an-dr-dev-write-documentation`](actions/an-dr-dev-write-documentation/SKILL.md) | Write human-facing documentation and check its claims. |
| [`an-dr-dev-write-readme`](actions/an-dr-dev-write-readme/SKILL.md) | Rewrite a README from what the repository actually contains. |
| [`an-dr-env-install-powershell`](actions/an-dr-env-install-powershell/SKILL.md) | Install or verify PowerShell 7 before running scripts. |
| [`an-dr-files-make-screengif`](actions/an-dr-files-make-screengif/SKILL.md) | Record an animated GIF of a website, application, or game, only on request. |
| [`an-dr-files-make-screenshot`](actions/an-dr-files-make-screenshot/SKILL.md) | Capture a website, GUI application, or game as documentation media. |
| [`an-dr-git-commit`](actions/an-dr-git-commit/SKILL.md) | Compose and record a commit in the unified message format. |
| [`an-dr-git-fix-commit-messages`](actions/an-dr-git-fix-commit-messages/SKILL.md) | Rewrite existing commit messages to that format. |
| [`an-dr-project-write-overview`](actions/an-dr-project-write-overview/SKILL.md) | Explain an unfamiliar repository in one HTML page, code first. |
| [`an-dr-text-analyze-slop`](actions/an-dr-text-analyze-slop/SKILL.md) | Analyze a text for slop and propose what to cut or say specifically. |
| [`an-dr-text-verify-claims`](actions/an-dr-text-verify-claims/SKILL.md) | Check a report or analysis against its sources and separate facts from inference and opinion. |

## Concepts

Passive. Principles the agent reads when their subject is in play and never runs. A concept holds only its `SKILL.md`.

| Skill | When to use |
| --- | --- |
| [`an-dr-concept-ai-slop`](concepts/an-dr-concept-ai-slop/SKILL.md) | Recognise and avoid slop: output that looks finished but costs the reader more than it gives. |
| [`an-dr-concept-clean-dependencies`](concepts/an-dr-concept-clean-dependencies/SKILL.md) | Apply clean-architecture rules to components: no cycles, no layer skipping, coherent components, public contracts only. |
| [`an-dr-concept-dark-cockpit`](concepts/an-dr-concept-dark-cockpit/SKILL.md) | Decide severity levels for problem-finding output: normal stays quiet, red is for critical alone. |
| [`an-dr-concept-evidence-grounding`](concepts/an-dr-concept-evidence-grounding/SKILL.md) | Keep conclusions traceable to evidence and separate observed, inferred, assumed, and intended statements. |
| [`an-dr-concept-single-authority`](concepts/an-dr-concept-single-authority/SKILL.md) | Give every fact and state one owner; mark every other copy as derived. |

## Conventions

Passive. The format rules for an artifact, with the checkers and generators that enforce them. The agent reads them when writing or reviewing that artifact.

| Skill | When to use |
| --- | --- |
| [`an-dr-convention-adr`](conventions/an-dr-convention-adr/SKILL.md) | Write ADRs in one format: location, numbering, template, and when a decision is immutable. |
| [`an-dr-convention-agent-skill`](conventions/an-dr-convention-agent-skill/SKILL.md) | Shape and write every skill alike: layout, kinds, description, sections, declared dependencies, registration. |
| [`an-dr-convention-artifact-layout`](conventions/an-dr-convention-artifact-layout/SKILL.md) | Locate generated artifacts: one run directory per day and letter, one subdirectory per kind. |
| [`an-dr-convention-code`](conventions/an-dr-convention-code/SKILL.md) | Write code to shared defaults: small changes, clear names, newcomer comments, reviewable commits. |
| [`an-dr-convention-commit-message`](conventions/an-dr-convention-commit-message/SKILL.md) | Write commit messages in the unified Conventional Commits format with no attribution. |
| [`an-dr-convention-html-report`](conventions/an-dr-convention-html-report/SKILL.md) | Write HTML reports in one format: brand, theme switch, problem levels, and offline Mermaid diagrams. |
| [`an-dr-convention-markdown`](conventions/an-dr-convention-markdown/SKILL.md) | Format Markdown: one line per paragraph, heading, list, fence, link, and table rules. |
| [`an-dr-convention-readme`](conventions/an-dr-convention-readme/SKILL.md) | Write READMEs to a fixed baseline order, with modules the evidence supports and nothing invented. |
| [`an-dr-convention-script`](conventions/an-dr-convention-script/SKILL.md) | Write skill scripts: PowerShell 7, non-interactive, tested, relayable output, folders passed in. |

## The repository itself

Skills that exist for maintaining and installing this repository itself. No skill outside this group depends on them.

| Skill | When to use |
| --- | --- |
| [`an-dr-agents-analyze-session`](_repository/an-dr-agents-analyze-session/SKILL.md) | Propose process improvements after integration or on request. |
| [`an-dr-agents-repo-build-dependencies`](_repository/an-dr-agents-repo-build-dependencies/SKILL.md) | Build the skill dependency diagram from the declarations and mark skills that declare none. |
| [`an-dr-agents-repo-convention-skills`](_repository/an-dr-agents-repo-convention-skills/SKILL.md) | Name this repository's skills <group>-<verb>[-<noun>] with a verb from its own list. |
| [`an-dr-agents-repo-install`](_repository/an-dr-agents-repo-install/SKILL.md) | Install this clone globally for local AI tools instead of per repository. |
| [`an-dr-agents-repo-modify`](_repository/an-dr-agents-repo-modify/SKILL.md) | Change this repository's own instructions and land them after approval. |
| [`an-dr-agents-repo-verify-installation`](_repository/an-dr-agents-repo-verify-installation/SKILL.md) | Diagnose why a tool is not picking up or following this workflow. |

Every name starts with `an-dr-`. Actions follow `<group>-<verb>`, with a noun when needed, with the verb taken from the list in `an-dr-agents-repo-convention-skills`; concepts and conventions follow `concept-<name>` and `convention-<name>`; the skills of this repository itself follow `agents-repo-<name>`. `an-dr-agents-repo-convention-skills` defines the rule and checks it.

To add a skill, create `skills/<category>/<name>/SKILL.md` with a matching `name`, a trigger-focused `description`, and the `an-dr.type` and `an-dr.dependencies` metadata that `agent-skill` defines. Add a PowerShell script only for repeated, mechanical operations and ensure it exits non-zero on failure. Register the skill in this table.
