---
name: an-dr-agents-repo-build-dependencies
description: Build a Mermaid dependency graph of a repository's skills from their an-dr.dependencies declarations and keep a Markdown block current. Use after adding, renaming, or re-declaring a skill, or when a dependency diagram needs refreshing.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message an-dr-convention-agent-skill
---

# Build skill dependencies

Defers: the `an-dr.dependencies` format to `an-dr-convention-agent-skill`.

## Build

```powershell
pwsh <skill>/scripts/build-dependencies.ps1 [-Root <repository>] [-Markdown <file>] [-Check]
```

- No `-Markdown` → prints the Mermaid diagram and a summary.
- `-Markdown <file>` → replaces the block between `<!-- skill-dependencies begin -->` and `<!-- skill-dependencies end -->`, keeping surrounding text; a file without both markers is an error.
- `-Check` → changes nothing; exits 1 when the block is stale or a skill is marked.
- Each category folder under `skills/` is a group; each name in `an-dr.dependencies` is an arrow; `none` and `PROHIBITED` draw none.

## Marks

- A skill with no `an-dr.dependencies` key is drawn dashed and listed after the diagram; a missing declaration differs from declaring none.
- A declared name matching no skill is listed.
- Fix both by declaring the key, as the registration check also requires.

## Output

The script prints a Markdown summary: skill and arrow counts, then marked skills and unknown names. Relay it with `an-dr-ai-send-message` and give the path of any rebuilt file.

## Rules

- Rebuild after every declaration change; never edit the generated block by hand.
- The script reads declarations only; whether a declaration matches what a skill names is the registration check's job.
