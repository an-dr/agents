---
name: agents-integration
description: Add the `agents` submodule plus a root `AGENTS.md`/`CLAUDE.md` to a host project adopting this workflow for the first time. Use when a repo has no `agents/` submodule yet, or to verify an existing one is fully wired up.
allowed-tools: PowerShell
---

# Agents integration

Onboards a host project onto this repo the same way `bones` and other existing consumers use it: `agents/` as a root submodule, a root `AGENTS.md` extending it, and a root `CLAUDE.md` pointing at both. Fully idempotent — safe to run against a repo that already has some or all of these; it only creates what's missing and never overwrites existing content.

## Usage

From the host repository's root:

```powershell
pwsh agents/skills/agents-integration/scripts/integrate.ps1
```

(If `agents/` doesn't exist yet, run this against a clone of this repo first, or fetch `scripts/integrate.ps1` directly — it only needs `git` and the target repo's own root, not to already be inside `agents/`.)

The script:

1. Adds `agents` as a git submodule (`https://github.com/an-dr/agents.git`) if `agents/` doesn't already exist.
2. Creates a root `AGENTS.md` with the standard "Primary instructions" section if none exists; inserts that section into an existing `AGENTS.md` that's missing it, leaving the rest of the file untouched (prepended above any existing title — safe over tidy; fix the heading order by hand afterward if it matters).
3. Adds a `## Commit scopes` section to the root `AGENTS.md` when it has none. The `git-commit` skill accepts only the scopes listed there.
4. Creates a root `CLAUDE.md` pointing at `agents/AGENTS.md` + `AGENTS.md` if none exists.

## After running

A fresh `AGENTS.md` gets a placeholder `## Project` section — fill it in with what the repo actually is (the "four START facts" `agents/AGENTS.md` itself asks for: problem, constraints, definition of done, exclusions, where knowable up front). This part can't be automated; it needs whatever context the person or agent running the script has about the project.
