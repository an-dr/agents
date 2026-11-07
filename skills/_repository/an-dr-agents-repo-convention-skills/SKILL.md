---
name: an-dr-agents-repo-convention-skills
description: The naming, metadata, and test rules of this repository's skills - the an-dr namespace, groups, verbs, type words, and agents-repo prefix - on top of the general skill convention. Use when naming, renaming, or reviewing a skill of this repository; check-names.ps1 in this skill enforces the names.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.4.0"
  an-dr.type: convention
  an-dr.dependencies: an-dr-ai-skill-implement-test an-dr-ai-skill-test an-dr-convention-agent-skill an-dr-dev-test an-dr-dev-write-documentation an-dr-git-commit an-dr-convention-agent-skill-testing
---

# Convention: this repository's skills

Defers: format, types, text, dependencies, and registration to `an-dr-convention-agent-skill`.

## Names

- Every name starts with `an-dr-`, because tools install skills side by side in one folder.
- Hyphens only; the Agent Skills format forbids underscores.

| Skill                            | Name after `an-dr-`                                           | Example                                     |
| -------------------------------- | ------------------------------------------------------------- | ------------------------------------------- |
| Action                           | `<group>-<verb>[-<noun>]`                                     | `an-dr-dev-test`, `an-dr-dev-verify-widget` |
| Concept                          | `concept-<name>`                                              | `an-dr-concept-resilience`                  |
| Convention                       | `convention-<name>`                                           | `an-dr-convention-changelog`                |
| Action on the repository         | `agents-repo-<verb>[-<noun>]`                                 | `an-dr-agents-repo-install-tool`            |
| Action on the agents' work       | `agents-<verb>[-<noun>]`                                      | `an-dr-agents-analyze-plan`                 |
| Repository concept or convention | `agents-repo-concept-<name>`, `agents-repo-convention-<name>` | `an-dr-agents-repo-convention-layout`       |

Groups: `ai` agent instructions and the conversation with the user; `ai-skill` implementing and executing skill behavior tests; `dev` developing software; `architecture` structure of components; `project` understanding a whole project; `text` texts the user brings in; `git` repository history; `files` media and other files; `env` the machine.

- The longest registered group matches before the verb is read.
- Verb: one lowercase word from the Verbs table.
- Noun: what the action acts on, one or more words; absent when group and verb already say it (`an-dr-dev-write-documentation`, `an-dr-git-commit`).
- A skill sits in the folder of its type; the repository's own skills sit in `_repository/`.

## Verbs

A verb is added here before use, with a meaning distinct from the others; `check-names.ps1` reads this table.

| Verb        | Means                                                                     |
| ----------- | ------------------------------------------------------------------------- |
| `analyze`   | examine a scope and report findings and proposals, changing nothing       |
| `assign`    | settle a value for a subject with the user and record it where it belongs |
| `build`     | assemble a derived artifact from its sources                              |
| `commit`    | record work in repository history                                         |
| `debug`     | find the cause of a concrete failure                                      |
| `design`    | explore a decision and its options before it is made                      |
| `fix`       | correct a defect that is known                                            |
| `follow`    | run a controller or process and keep to its rules                         |
| `implement` | build working code or tests from a design                                 |
| `install`   | put something on a machine                                                |
| `integrate` | land an approved branch in the default branch                             |
| `make`      | create a media file or other artifact                                     |
| `modify`    | change something that exists, in place                                    |
| `review`    | judge a change or a text and give a verdict                               |
| `send`      | communicate with the user                                                 |
| `test`      | exercise code or agent behavior against test expectations                 |
| `verify`    | check a result against criteria or sources                                |
| `write`     | produce a document or a report                                            |

## Metadata

- Frontmatter: `license: MIT`; `author` and `version` under `metadata`, beside the `an-dr.` extensions.
- `version` is a quoted semantic version (`"1.0.0"`), raised when the skill's behaviour changes.

## Tests

- Suites, fixtures, environment requirements, and deterministic test layout follow `an-dr-convention-agent-skill-testing`.
- Coverage is authored by `an-dr-ai-skill-implement-test`; checks and explicitly requested evaluations are run by `an-dr-ai-skill-test`.
- The root check command discovers local script runners and validates evaluation data without invoking models.

## Check

- `scripts/check-names.ps1` verifies every skill name against the naming tables, reading verbs from the Verbs table, and exits non-zero on any break.
- Its regression test breaks a copy one way at a time and expects each break named; the repository test run also checks the required test layout.
