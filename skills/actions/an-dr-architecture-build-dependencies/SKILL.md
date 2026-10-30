---
name: an-dr-architecture-build-dependencies
description: Build the dependency graph of a repository's skills from their an-dr.dependencies declarations as a Mermaid diagram, mark every skill that declares none, and keep a Markdown block current. Use after adding, renaming, or re-declaring a skill, when a dependency diagram needs refreshing, or when you need to see what depends on what.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message an-dr-convention-agent-skill
---

# Build skill dependencies

Turns the `an-dr.dependencies` that every skill declares, as `an-dr-convention-agent-skill` defines them, into one picture. A script does the work, so the diagram is always derived from the declarations and never edited by hand.

## Build

```powershell
pwsh <skill>/scripts/build-dependencies.ps1 [-Root <repository>] [-Markdown <file>] [-Check]
```

- Without `-Markdown`, it prints the Mermaid diagram and a summary.
- With `-Markdown <file>`, it replaces the block between `<!-- skill-dependencies begin -->` and `<!-- skill-dependencies end -->` in that file, so the surrounding text stays. A file without the two markers is an error.
- With `-Check`, it changes nothing and exits 1 when the block is stale or a skill is marked below.

Each category folder under `skills/` is a group, and each name in a skill's `an-dr.dependencies` is an arrow. `none` and `PROHIBITED` draw no arrow.

## Marks

A skill whose frontmatter has no `an-dr.dependencies` key is drawn with a dashed outline and listed after the diagram, because a missing declaration is different from declaring none. A declared name that matches no skill is listed too. Fix both by declaring the key, as the registration check also requires.

## Output

The script prints a Markdown summary: the skill and arrow counts, then the marked skills and unknown names. Relay it to the user with `an-dr-ai-send-message`, and give the path of any file it rebuilt.

## Rules

- Rebuild after every change to a declaration; never edit the generated block by hand.
- The script reads declarations only. Whether a declaration matches what a skill names is the registration check's job.
