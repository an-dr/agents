---
name: an-dr-agents-repo-convention-skills
description: How the skills of this repository are named - the an-dr namespace, then a group and a verb from this repository's own list, with a noun when the verb alone is not enough, for actions, a type word for concepts and conventions, and the agents-repo prefix for the repository's own skills - on top of the general skill convention. Use when naming, renaming, or reviewing a skill of this repository; check-names.ps1 in this skill enforces the names.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: convention
  an-dr.dependencies: an-dr-ai-skill-implement-test an-dr-ai-skill-test an-dr-convention-agent-skill an-dr-dev-test an-dr-dev-write-documentation an-dr-git-commit
---

# Convention: this repository's skills

Every skill here follows `an-dr-convention-agent-skill`, the general convention for the format, types, text, dependencies, and registration. This convention adds the naming and metadata rules that belong to this repository, so that the names in a tool's skill list read alike, sort by kind, and never collide with another author's skills.

## Names

Every name starts with `an-dr-`, the namespace of this repository's author, because tools install skills side by side in one folder. Hyphens only: the Agent Skills format does not allow underscores in a name. After the namespace:

| Skill | Name | Example |
| --- | --- | --- |
| Action | `<group>-<verb>`, or `<group>-<verb>-<noun>` | `an-dr-dev-test`, `an-dr-dev-verify-widget` |
| Concept | `concept-<name>` | `an-dr-concept-resilience` |
| Convention | `convention-<name>` | `an-dr-convention-changelog` |
| Of the repository itself | `agents-repo-<verb>[-<noun>]` for an action on the repository, `agents-<verb>[-<noun>]` for an action on the agents' own work, `agents-repo-concept-<name>` or `agents-repo-convention-<name>` for a concept or convention | `an-dr-agents-repo-install-tool`, `an-dr-agents-analyze-plan`, `an-dr-agents-repo-convention-layout` |

- **Group:** the area an action works in: `ai` for agent instructions and the conversation with the user, `ai-skill` for implementing and executing skill behavior tests, `dev` for developing software, `architecture` for the structure of components, `project` for understanding a whole project, `text` for texts the user brings in, `git` for repository history, `files` for media and other files, `env` for the machine. Match the longest registered group before reading the verb.
- **Verb:** one word from the list below, in lowercase.
- **Noun:** what the action acts on, one or more words. Leave it out when the group and verb already say it, as in `an-dr-dev-write-documentation` or `an-dr-git-commit`.

## Verbs

The verbs are this repository's own, so each name says exactly what the action does. Add a verb here before using it, and keep the meanings distinct: `check-names.ps1` reads this table, so the list has one owner.

| Verb | Means |
| --- | --- |
| `analyze` | examine a scope and report findings and proposals, changing nothing |
| `build` | assemble a derived artifact from its sources |
| `commit` | record work in repository history |
| `debug` | find the cause of a concrete failure |
| `design` | explore a decision and its options before it is made |
| `fix` | correct a defect that is known |
| `follow` | run a controller or process and keep to its rules |
| `implement` | build working code or tests from a design |
| `install` | put something on a machine |
| `integrate` | land an approved branch in the default branch |
| `make` | create a media file or other artifact |
| `modify` | change something that exists, in place |
| `review` | judge a change or a text and give a verdict |
| `send` | communicate with the user |
| `test` | exercise code or agent behavior against test expectations |
| `verify` | check a result against criteria or sources |
| `write` | produce a document or a report |

A skill sits in the folder of its type, and the skills of the repository itself sit in the underscore folder `_repository/`.

## Metadata

Every skill carries `license: MIT` as a standard frontmatter field, and `author` and `version` under `metadata`, next to the `an-dr.` extensions the general convention defines. The version is a quoted semantic version such as `"1.0.0"`; raise it when the skill's behaviour changes.

## Tests

Every skill, including a concept or convention, has a tracked `tests/` folder containing `cases.json` with observable behavior cases. Implement cases and script tests through `an-dr-ai-skill-implement-test`. Keep executable script tests as `tests/test-*.ps1`, fixtures beneath `tests/fixtures/`, and production code in `scripts/`.

Every `scripts/` folder contains `run-tests.ps1`, a non-interactive entry point that runs the skill's top-level script tests in fresh PowerShell processes, preserves failures, and exits non-zero if any test fails or no script tests exist. It never runs `cases.json` or agent evaluations. A runner is local to its skill; it must not import another skill's test implementation.

Run cheap tests through `an-dr-ai-skill-test` after modifications. The repository's root test command discovers these local runners instead of searching for individual test scripts. It validates case structure separately; behavioral execution remains on demand. Syntax checks may establish a baseline for a legacy script but do not establish runtime behavior or replace regression tests for changed logic.

## Check

```powershell
pwsh <skill>/scripts/check-names.ps1 [-Root <repository>]
```

The script reads the verbs from the table above. It reports every skill that breaks the naming table and exits non-zero on any. `tests/test-check-names.ps1` breaks a copy one way at a time and expects each break to be named. Run it through `pwsh <skill>/scripts/run-tests.ps1`. The root test command also checks the required test layout.
