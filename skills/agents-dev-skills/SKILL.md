---
name: agents-dev-skills
description: Create, rename, or restructure a skill in this agents repository — its directory, frontmatter, scripts and their tests, the shared skills it must build on, and its registration. Use whenever a skill is added or its shape changes; ai-prompt-writing owns how its rules are worded.
metadata:
  dependencies: agents-modify agents-ui ai-prompt-writing concept-clean-dependencies concept-dark-cockpit concept-evidence-grounding concept-single-authority convention-adr convention-agent-skill convention-artifact-layout convention-code convention-commit-message convention-markdown convention-script docs-html-report git-commit
---

# Developing skills

A skill is one directory, `skills/<name>/`, holding `SKILL.md` and, when it does mechanical work, `scripts/` and `assets/`. Word its rules through `ai-prompt-writing`; this skill owns the shape around them.

## Shape

The directory, naming, frontmatter, kinds of skill, text structure, declared dependencies, and registration format are `convention-agent-skill`. Scripts follow `convention-script`. Apply `concept-clean-dependencies` when a skill depends on another: the graph stays acyclic, a skill reaches another only through its public command or rule, and a foundation skill never names its consumers.

## Shared skills it must build on

A skill does not restate what one of these owns; it names the skill at the point of use.

| When the skill... | It uses |
| --- | --- |
| shows a table, asks, offers a choice, or asks to confirm | `agents-ui` — always, with no skill-specific question format |
| reports findings, checks, or risks | `agents-ui`'s finding levels in chat and Markdown, `docs-html-report` in HTML; only those two apply `concept-dark-cockpit` |
| states facts about code, a repository, or a source | `concept-evidence-grounding` |
| keeps a fact or state in more than one place | `concept-single-authority` |
| writes a file that is not repository content | `convention-artifact-layout`, directory from `convention-artifact-layout` |
| writes an HTML page | `docs-html-report` |
| writes Markdown | `convention-markdown`, checked by `convention-markdown` |
| writes a script | `convention-script` |
| writes code | `convention-code` |
| writes an ADR | `convention-adr` |
| commits | `git-commit`, message format `convention-commit-message` |

## Registration

Register the skill as `convention-agent-skill` requires, then run the checks that `agents-modify` owns; every change here lands through it.
