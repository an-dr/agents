---
name: agents-dev-skills
description: Create, rename, or restructure a skill in this agents repository — its directory, frontmatter, scripts and their tests, and its registration. Use whenever a skill is added or its shape changes.
metadata:
  dependencies: concept-clean-dependencies convention-agent-skill convention-script
---

# Developing skills

A skill is one directory, `skills/<name>/`, holding `SKILL.md` and, when it does mechanical work, `scripts/` and `assets/`. This skill owns the shape around a skill's rules.

## Shape

The directory, naming, frontmatter, kinds of skill, text structure, declared dependencies, and registration format are `convention-agent-skill`. Scripts follow `convention-script`. Apply `concept-clean-dependencies` when a skill depends on another: the graph stays acyclic, a skill reaches another only through its public command or rule, and a foundation skill never names its consumers.

## Registration

Register the skill as `convention-agent-skill` requires.
