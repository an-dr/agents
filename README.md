# agents

An executable AI development workflow focused on reliable engineering rather than conversational memory.

`AGENTS.md` defines policy. Before changing files, the agent asks the user to select Direct, Quick, Detailed, or Detailed Auto unless the user already selected a workflow or one is active. Direct completes and delivers the request without approval gates or workflow state. `skills/an-dr-dev-follow-workflow/scripts/workflow.ps1` enforces the gated flows' phase transitions and stores committable state in `.progress/workflow.json`. Before integration, `an-dr-dev-integrate` removes that state from every feature-branch commit.

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

- `AGENTS.md` — concise policy and entry point, including the pointer to the skill catalog
- `skills/` — one self-contained folder per skill in the [Agent Skills](https://agentskills.io/specification) format, grouped in four categories; `skills/README.md` lists them
- `skills/actions/` — procedures the agent runs, such as `an-dr-dev-follow-workflow`, the executable workflow state machine, and `an-dr-git-commit`, which records commits
- `skills/concepts/` and `skills/conventions/` — passive skills: principles and format rules the agent reads when their subject is in play, such as `an-dr-convention-commit-message`, whose checker rejects AI co-author and generator trailers, and `an-dr-convention-agent-skill`, which defines the skill format, its `an-dr.type` and `an-dr.dependencies` extensions, and the registration check
- `skills/_repository/` — the skills that maintain and install this repository: `an-dr-agents-repo-install` for global installation, `an-dr-agents-repo-modify` for changing the instructions from a host project, `an-dr-agents-repo-verify-installation`, and `an-dr-agents-analyze-session`
- `tests/run-all.ps1` — runs every skill test and repository check; CI runs it on each push
- `.artifacts/ai-<YYYY-MM-DD>-<N>/` — ignored per-run directory holding that run's review JSON, rendered HTML, and reports; `an-dr-convention-artifact-layout` owns the layout

## Development analysis

The analysis skills cover distinct tasks: `an-dr-dev-analyze-slop` inspects selected changes, a branch diff, files, directories, or a whole repository for illogical or questionable code and documentation artifacts and proposes changes in a prioritized HTML findings table; `an-dr-dev-review` reviews a diff and judges the lines it adds against `an-dr-concept-ai-slop`; and `an-dr-dev-analyze-changes` explains a delivered change in HTML and prepares the full-branch integration handoff.

## Skills stay portable

Each skill runs from its own folder, so it works whether it is installed with the rest of this repository, on its own, or through another tool. No code is shared through a folder outside `skills/<name>/`. When one skill's script needs another skill, it calls that skill's public script, and the agent passes the other skill's folder as a parameter, for example `-CommitMessageSkill <an-dr-convention-commit-message>`. The script never guesses where the other skill is installed. Small generic helpers are copied into each skill that needs them. `skills/an-dr-convention-agent-skill/` states the rules, and its `check-registration.ps1` enforces them.

## Skill dependencies

This diagram is built from the `an-dr.dependencies` each skill declares in its [instructions](skills/README.md) by `an-dr-agents-repo-build-dependencies`, which marks any skill that declares none. A skill declares every skill it names, and `check-registration.ps1` fails on a skill that names an undeclared one, declares one it never names, or sits on a dependency cycle. `PROHIBITED` marks a stable skill, such as a concept, that must name no other skill.

Arrows point from a skill to a skill it names. Groups are the category folders under `skills/`; no skill outside the agents repository's group depends on one inside it. Skills that name no skill and are named by none are omitted, and transitive dependencies are reached by following arrows.

<!-- skill-dependencies begin -->

```mermaid
flowchart LR
    subgraph g_repository["Repository"]
        an-dr-agents-analyze-session
        an-dr-agents-repo-build-dependencies
        an-dr-agents-repo-convention-skills
        an-dr-agents-repo-install
        an-dr-agents-repo-modify
        an-dr-agents-repo-verify-installation
    end
    subgraph g_actions["Actions"]
        an-dr-ai-review-instruction
        an-dr-ai-send-message
        an-dr-ai-write-instruction
        an-dr-architecture-fix-dependencies
        an-dr-dev-analyze-changes
        an-dr-dev-analyze-slop
        an-dr-dev-debug
        an-dr-dev-design
        an-dr-dev-follow-workflow
        an-dr-dev-implement-adversarial-ut
        an-dr-dev-implement-code
        an-dr-dev-integrate
        an-dr-dev-review
        an-dr-dev-test
        an-dr-dev-write-documentation
        an-dr-dev-write-readme
        an-dr-env-install-powershell
        an-dr-files-make-screengif
        an-dr-files-make-screenshot
        an-dr-git-commit
        an-dr-git-fix-commit-messages
        an-dr-project-write-overview
        an-dr-text-analyze-slop
        an-dr-text-verify-claims
    end
    subgraph g_concepts["Concepts"]
        an-dr-concept-ai-slop
        an-dr-concept-clean-dependencies
        an-dr-concept-dark-cockpit
        an-dr-concept-evidence-grounding
        an-dr-concept-single-authority
    end
    subgraph g_conventions["Conventions"]
        an-dr-convention-adr
        an-dr-convention-agent-skill
        an-dr-convention-artifact-layout
        an-dr-convention-code
        an-dr-convention-commit-message
        an-dr-convention-html-report
        an-dr-convention-markdown
        an-dr-convention-readme
        an-dr-convention-script
    end
    an-dr-agents-analyze-session --> an-dr-agents-repo-modify
    an-dr-agents-repo-build-dependencies --> an-dr-ai-send-message & an-dr-convention-agent-skill
    an-dr-agents-repo-convention-skills --> an-dr-convention-agent-skill & an-dr-dev-test & an-dr-dev-write-documentation & an-dr-git-commit
    an-dr-agents-repo-modify --> an-dr-agents-repo-convention-skills & an-dr-agents-repo-install & an-dr-agents-repo-verify-installation & an-dr-ai-review-instruction & an-dr-ai-send-message & an-dr-ai-write-instruction & an-dr-convention-agent-skill & an-dr-convention-markdown & an-dr-convention-script & an-dr-git-commit
    an-dr-agents-repo-verify-installation --> an-dr-agents-repo-install & an-dr-convention-commit-message
    an-dr-ai-review-instruction --> an-dr-ai-send-message
    an-dr-ai-send-message --> an-dr-concept-dark-cockpit & an-dr-convention-artifact-layout
    an-dr-ai-write-instruction --> an-dr-ai-review-instruction & an-dr-concept-ai-slop & an-dr-convention-markdown
    an-dr-architecture-fix-dependencies --> an-dr-ai-send-message & an-dr-concept-clean-dependencies & an-dr-convention-artifact-layout & an-dr-convention-html-report
    an-dr-dev-analyze-changes --> an-dr-ai-send-message & an-dr-concept-ai-slop & an-dr-convention-adr & an-dr-convention-artifact-layout & an-dr-convention-html-report & an-dr-dev-review & an-dr-dev-write-documentation
    an-dr-dev-analyze-slop --> an-dr-ai-review-instruction & an-dr-ai-send-message & an-dr-concept-ai-slop & an-dr-convention-artifact-layout & an-dr-convention-html-report
    an-dr-dev-design --> an-dr-ai-send-message & an-dr-convention-adr
    an-dr-dev-follow-workflow --> an-dr-ai-send-message & an-dr-convention-adr & an-dr-dev-analyze-changes & an-dr-dev-design & an-dr-dev-implement-code & an-dr-dev-integrate & an-dr-dev-review & an-dr-dev-test & an-dr-dev-write-documentation & an-dr-git-commit
    an-dr-dev-implement-code --> an-dr-convention-adr & an-dr-convention-code & an-dr-dev-write-documentation
    an-dr-dev-integrate --> an-dr-ai-send-message & an-dr-convention-commit-message & an-dr-git-commit
    an-dr-dev-review --> an-dr-ai-send-message & an-dr-concept-ai-slop & an-dr-concept-clean-dependencies & an-dr-concept-evidence-grounding & an-dr-convention-artifact-layout & an-dr-convention-code & an-dr-convention-html-report
    an-dr-dev-test --> an-dr-ai-send-message & an-dr-dev-implement-adversarial-ut
    an-dr-dev-write-documentation --> an-dr-ai-send-message & an-dr-concept-ai-slop & an-dr-convention-markdown
    an-dr-dev-write-readme --> an-dr-ai-send-message & an-dr-convention-markdown & an-dr-convention-readme & an-dr-dev-write-documentation & an-dr-files-make-screengif & an-dr-files-make-screenshot
    an-dr-env-install-powershell --> an-dr-ai-send-message
    an-dr-files-make-screengif --> an-dr-files-make-screenshot
    an-dr-files-make-screenshot --> an-dr-convention-artifact-layout
    an-dr-git-commit --> an-dr-convention-commit-message
    an-dr-git-fix-commit-messages --> an-dr-convention-commit-message
    an-dr-project-write-overview --> an-dr-concept-ai-slop & an-dr-convention-artifact-layout & an-dr-convention-html-report & an-dr-dev-write-documentation
    an-dr-text-analyze-slop --> an-dr-ai-send-message & an-dr-concept-ai-slop & an-dr-convention-artifact-layout & an-dr-convention-html-report
    an-dr-text-verify-claims --> an-dr-ai-send-message & an-dr-convention-artifact-layout & an-dr-convention-html-report
    an-dr-convention-agent-skill --> an-dr-concept-clean-dependencies & an-dr-convention-script
    an-dr-convention-code --> an-dr-concept-ai-slop & an-dr-concept-clean-dependencies
    an-dr-convention-html-report --> an-dr-concept-dark-cockpit & an-dr-convention-artifact-layout
    an-dr-convention-readme --> an-dr-concept-ai-slop & an-dr-concept-evidence-grounding & an-dr-convention-markdown
    an-dr-convention-script --> an-dr-ai-send-message
```

<!-- skill-dependencies end -->

Script inspection reveals dependencies the instructions do not name: `an-dr-agents-repo-modify` loads `an-dr-agents-repo-install`'s module to locate the clone, and `an-dr-agents-repo-verify-installation` runs its verifier unless the install check is skipped.

The [PowerShell bootstrap skill](skills/actions/an-dr-env-install-powershell/SKILL.md) applies before running skill scripts when PowerShell 7 is unavailable.

## Checks

```powershell
pwsh tests/run-all.ps1
```

It prints one table of results and exits non-zero when any step fails.
