# agents

An executable AI development workflow focused on reliable engineering rather than conversational memory.

`AGENTS.md` defines policy. Before changing files, the agent asks the user to select Direct, Quick, Detailed, or Detailed Auto unless the user already selected a workflow or one is active. Direct completes and delivers the request without approval gates or workflow state. `skills/dev-workflow/scripts/workflow.ps1` enforces the gated flows' phase transitions and stores committable state in `.progress/workflow.json`. Before integration, `dev-workflow-clean-branch` removes that state from every feature-branch commit.

In the gated-flow diagrams below, 👤 marks a transition the user's own words drive. Every other edge is the agent's to take.

## Direct

When the user selects Direct, the agent works on the current branch, chooses a sound approach, updates needed documentation, implements, reviews, runs relevant checks, fixes findings, and delivers the result in the same request. It creates no `.progress/` state and asks no further workflow approvals. Verified work is committed locally; pushing still requires the user's request. Changes to this process repository remain uncommitted for the user's review under its own scope rule.

```mermaid
flowchart LR
REQUEST --> WORK --> REVIEW --> DELIVERY
REVIEW -->|issues| WORK
```

## Detailed

For multi-increment, architectural, or public-interface work. INTAKE, DESIGN, and SPLIT only read and ask; they accumulate what the user wants as requests and what the user must decide as questions, and change nothing. Three commands drive the flow — **intake** closes the request list, **implement** releases the plan into code, **integrate** lands the reviewed branch — and between them the user still verifies each increment.

```mermaid
flowchart TD
INTAKE -->|👤 adds a request| INTAKE
INTAKE -->|👤 says the list is complete| DESIGN --> SPLIT
SPLIT -->|👤 says implement| BRANCH --> BUILD --> VERIFY
VERIFY -->|👤 verifies the increment| COMMIT
VERIFY -->|issues| BUILD
COMMIT -->|more increments| BUILD
COMMIT -->|plan complete| SUMMARY
SUMMARY -->|👤 says integrate| INTEGRATE
```

The controller refuses the implement approval while any question is still open, so nothing is built on an unanswered assumption.

## Detailed Auto

Runs the same phases, reviews, tests, commits, and integration preparation as Detailed, and keeps the same three commands. What it automates is the middle: the agent verifies and commits each increment itself, so the user closes intake, approves the plan, and is not asked again until the final review.

```mermaid
flowchart TD
INTAKE -->|👤 adds a request| INTAKE
INTAKE -->|👤 says the list is complete| DESIGN --> SPLIT
SPLIT -->|👤 says implement| BRANCH --> BUILD --> VERIFY
VERIFY -->|agent verifies| COMMIT
VERIFY -->|issues| BUILD
COMMIT -->|more increments| BUILD
COMMIT -->|plan complete| SUMMARY --> FINAL_REVIEW
FINAL_REVIEW -->|👤 says integrate| INTEGRATE
```

## Quick

For one small, self-contained change with a handful of clear design choices. It uses one build/verify/commit pass on the current branch, behind the same implement command.

```mermaid
flowchart TD
INTAKE --> DESIGN
DESIGN -->|👤 says implement| BUILD --> VERIFY
VERIFY -->|👤 verifies the change| COMMIT
VERIFY -->|issues| BUILD
```

## Integration

`INTEGRATE` always rebases, so the default branch never gains a merge commit. 👤 The user then chooses how the branch lands, and the skill asks every time:

| Mode | Result |
| --- | --- |
| Commits | every commit is kept and the base fast-forwards |
| Regroup | the branch is rebuilt as a few logical commits and the base fast-forwards |
| Squash | the branch becomes one commit and the base fast-forwards |
| Request | the branch becomes one commit, is pushed, and a pull request is opened |
| RebaseMerge | the branch is regrouped, pushed as a pull request, and landed by the platform's rebase and merge once CI passes |

Future Detailed increments can be inserted or reordered without changing active or completed increment identity. The controller validates approvals, branches, commits, and legal transitions before saving state atomically. Every controller change prints user-presentable Markdown tables for the workflow phases and increment statuses.

## Repository layout

- `AGENTS.md` — concise policy and entry point, including the skill table every tool reads
- `skills/` — one self-contained folder per skill; `skills/README.md` lists them with the same one-line uses as `AGENTS.md`
- `skills/dev-workflow/` — executable workflow state machine
- `skills/git-commit/` — the commit message format and its checker. Commits are attributed to the person who records them; the checker rejects AI co-author and generator trailers
- `skills/agents-install/` — global installation for local AI tools
- `skills/agents-modify/` — changing this repository's own instructions from a host project, and the registration check
- `skills/install-powershell/` — PowerShell 7 bootstrap instructions
- `tests/run-all.ps1` — runs every skill test and repository check; CI runs it on each push
- `.artifacts/ai-<YYYY-MM-DD>-<N>/` — ignored per-run directory holding that run's review JSON, rendered HTML, and reports; `skills/convention-artifact-layout/` owns the layout

## Development analysis

The analysis skills cover distinct tasks: `dev-analysis-deslop` inspects selected changes, a branch diff, files, directories, or a whole repository for illogical or questionable code and documentation artifacts and proposes changes in a prioritized HTML findings table; `dev-analysis-review` reviews a diff and includes a deslop pass over the same scope; `dev-analysis-change` explains a delivered change in HTML; and `dev-analysis-summary` prepares the full-branch integration handoff.

## Skills stay portable

Each skill runs from its own folder, so it works whether it is installed with the rest of this repository, on its own, or through another tool. No code is shared through a folder outside `skills/<name>/`. When one skill's script needs another skill, it calls that skill's public script, and the agent passes the other skill's folder as a parameter, for example `-ConventionCommitMessageSkill <convention-commit-message>`. The script never guesses where the other skill is installed. Small generic helpers are copied into each skill that needs them. `skills/convention-agent-skill/` states the rules, and its `check-registration.ps1` enforces them.

## Skill dependencies

This diagram maps direct operational dependencies in the [skill instructions](skills/README.md) and their scripts, including work delegated by the agent. Each skill's `metadata.dependencies` declares every skill it names, and `check-registration.ps1` fails on a skill that names an undeclared one. `PROHIBITED` marks a stable skill, such as a concept, that must name no other skill, and the checker lists every dependency cycle with its path.

Arrows point from a consumer to a skill it invokes or whose rules it uses. Solid arrows apply to the normal procedure; dashed arrows name a condition or handoff. Groups organise the view by current role, not installation boundaries. Cycles reflect the current instructions, including conditional collaboration, rather than recursive script calls. Examples, comparisons, and workflow ordering alone do not create edges. Skills without a relationship are omitted, and transitive dependencies are reached by following arrows.

```mermaid
flowchart LR
    subgraph maintenance["Maintaining the skills"]
        agents-dev-skills
        agents-modify
        ai-prompt-writing
        agents-health-check
        agents-install
        agents-retro
        install-powershell
    end
    subgraph workflow["Workflow and Git"]
        dev-workflow
        dev-design
        dev-build
        dev-testing
        dev-untangle-dependencies
        dev-analysis-summary
        git-integrate
        git-commit-fix
        dev-workflow-clean-branch
        ut-adversarial
    end
    subgraph analysis["Analysis and reports"]
        dev-analysis-review
        dev-analysis-deslop
        dev-analysis-change
        dev-analysis-project-overview
        text-claim-audit
        ai-prompt-review
    end
    subgraph documentation["Documentation and media"]
        docs-writing
        docs-readme
        docs-screenshot
        docs-gif
    end
    subgraph shared["Shared services"]
        docs-html-report
        agents-ui
        git-commit
    end
    subgraph concepts["Concepts"]
        concept-clean-dependencies
        concept-dark-cockpit
        concept-evidence-grounding
        concept-single-authority
    end
    subgraph conventions["Conventions"]
        convention-adr
        convention-agent-skill
        convention-artifact-layout
        convention-code
        convention-commit-message
        convention-markdown
        convention-readme
        convention-script
    end
    dev-analysis-change --> convention-artifact-layout
    dev-analysis-deslop --> convention-artifact-layout
    dev-analysis-review --> convention-artifact-layout
    dev-analysis-project-overview --> convention-artifact-layout
    docs-html-report --> convention-artifact-layout
    agents-ui -. saved question rounds .-> convention-artifact-layout
    docs-screenshot -. scratch captures .-> convention-artifact-layout
    text-claim-audit -. more than 15 ledger rows .-> convention-artifact-layout
    dev-analysis-review --> dev-analysis-deslop & dev-build & docs-html-report
    dev-analysis-deslop --> docs-html-report & agents-ui
    dev-analysis-change --> docs-writing & docs-html-report
    dev-analysis-project-overview --> docs-writing & docs-html-report
    dev-analysis-summary --> dev-analysis-review & dev-analysis-change & agents-ui
    dev-analysis-summary -. reconcile draft ADRs .-> convention-adr
    text-claim-audit --> agents-ui
    text-claim-audit -. more than 15 ledger rows .-> docs-html-report
    docs-html-report -. renders finding levels .-> concept-dark-cockpit
    ai-prompt-review --> agents-ui
    agents-ui -. renders finding levels in text .-> concept-dark-cockpit
    agents-dev-skills --> concept-clean-dependencies
    dev-build --> concept-clean-dependencies
    dev-analysis-review --> concept-clean-dependencies & concept-evidence-grounding
    text-claim-audit --> concept-evidence-grounding
    docs-readme --> concept-evidence-grounding
    dev-analysis-project-overview --> concept-evidence-grounding
    dev-workflow --> concept-single-authority
    git-commit --> convention-commit-message
    git-commit-fix --> convention-commit-message
    agents-dev-skills --> convention-script & convention-agent-skill
    ai-prompt-writing --> convention-agent-skill
    agents-modify --> convention-agent-skill
    ai-prompt-review --> convention-agent-skill
    convention-agent-skill --> convention-script & concept-clean-dependencies
    dev-build --> convention-code
    dev-untangle-dependencies --> concept-clean-dependencies & convention-agent-skill
    dev-untangle-dependencies -. changes to this repository .-> agents-modify
    dev-untangle-dependencies --> docs-html-report & convention-artifact-layout
    dev-untangle-dependencies -. approval and questions .-> agents-ui
    dev-build --> docs-writing
    dev-build -. architectural contract or ADR exception .-> convention-adr
    dev-build -. gated documentation questions .-> dev-workflow
    dev-design --> agents-ui
    dev-design -. architectural decision .-> convention-adr
    dev-design -. controller questions .-> dev-workflow
    dev-testing --> agents-ui
    dev-testing -. systematic bug hunt .-> ut-adversarial
    docs-writing --> convention-markdown
    docs-writing -. README rewrite .-> docs-readme
    docs-writing -. blocking documentation conflict .-> agents-ui
    docs-readme --> convention-readme & convention-markdown & docs-writing
    convention-readme --> convention-markdown
    docs-readme -. visible application output .-> docs-screenshot
    docs-readme -. requested animation .-> docs-gif
    docs-readme -. open questions .-> agents-ui
    docs-gif --> docs-screenshot
    dev-workflow --> docs-writing & dev-build & dev-testing & dev-analysis-review & git-commit & agents-ui
    dev-workflow -. deeper design decision .-> dev-design
    dev-workflow -. architectural decision .-> convention-adr
    dev-workflow -. Detailed branch summary .-> dev-analysis-summary
    dev-workflow -. Detailed integration .-> dev-workflow-clean-branch & git-integrate
    git-integrate --> dev-workflow-clean-branch & agents-ui
    git-integrate -. compose or validate messages .-> git-commit
    git-commit-fix --> git-commit
    git-commit-fix -. history also needs regrouping .-> git-integrate
    agents-dev-skills --> ai-prompt-writing & agents-ui & agents-modify
    agents-modify --> ai-prompt-writing & convention-markdown & ai-prompt-review & agents-install
    agents-modify -. skill layout changes .-> agents-dev-skills
    agents-modify -. questions or plan confirmation .-> agents-ui
    agents-modify -. approved commit .-> git-commit
    ai-prompt-writing --> convention-markdown & ai-prompt-review
    ai-prompt-writing -. edits to this repository .-> agents-modify
    ai-prompt-writing -. skill layout changes .-> agents-dev-skills
    ai-prompt-writing -. added or moved instructions .-> agents-health-check
    agents-health-check -. machine install check .-> agents-install
    agents-health-check -. loaded policy still misbehaves .-> agents-retro
    agents-retro -. approved amendment .-> agents-modify
    agents-retro -. code finding handoff .-> dev-analysis-review
    install-powershell -. package installation approval .-> agents-ui
```

Eight skills directly use `convention-artifact-layout`: five always produce stored reports, while `agents-ui`, `docs-screenshot`, and `text-claim-audit` use it for conditional outputs. Other skills reach storage transitively. Script inspection also reveals dependencies the instructions do not name: `agents-modify` loads `agents-install`'s module to locate the clone, and `agents-health-check` runs its verifier unless the install check is skipped.

The [shared-skill rules](skills/agents-dev-skills/SKILL.md#shared-skills-it-must-build-on) additionally apply by activity: tables and questions use `agents-ui`, findings use `agents-ui` in chat and `docs-html-report` in HTML, the only skills that apply `concept-dark-cockpit`, facts about a source use `concept-evidence-grounding`, state kept in several places uses `concept-single-authority`, generated artifacts use `convention-artifact-layout`, HTML uses `docs-html-report`, Markdown uses `convention-markdown`, scripts use `convention-script`, code uses `convention-code`, ADRs use `convention-adr`, and commits use `git-commit` with `convention-commit-message`. The [PowerShell bootstrap skill](skills/install-powershell/SKILL.md) applies before running skill scripts when PowerShell 7 is unavailable. These activity-based requirements apply even where a skill does not repeat the dependency by name; the diagram shows the specific operational relationships rather than expanding those rules into an edge from every possible caller.

## Checks

```powershell
pwsh tests/run-all.ps1
```

It prints one table of results and exits non-zero when any step fails.
