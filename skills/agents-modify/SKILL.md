---
name: agents-modify
description: Change this workflow repository's own instructions — AGENTS.md, roles, skills, and their scripts — from wherever the need appeared, then summarize the change and, once the user approves, commit and push it. Use when work in another repository shows that the agent instructions themselves must change.
allowed-tools: PowerShell, Read, Grep, Glob, Write, Edit
---

# Modify the agents repository

The instruction set is used from other repositories, so that is where its defects appear: a rule misfires in a host project, and the fix belongs in the clone rather than in a note that only this conversation remembers. This skill finds that clone from wherever the agent is working, changes it under the `agent-developer` role, and lands it behind one explicit approval.

`agents-retro` decides *what* to amend after a Detailed flow. This skill is *how* an amendment reaches the clone, whatever proposed it.

## Locate the clone

```powershell
pwsh <clone>/skills/agents-modify/scripts/find-agents-root.ps1 [-Path <start-directory>] [-AgentsRoot <path>]
```

It looks for the clone providing this skill (following the junction of a global install), the repository being worked in, an `agents` submodule inside it, and the policy path in each tool's `agents-install` block. It prints a candidate table, then the resolved root's branch, working tree, upstream, and whether it is nested in the host repository.

| Exit | Meaning | Do |
| --- | --- | --- |
| `0` | one clone resolved | work in the printed root |
| `1` | no clone found | ask the user where their clone is, then re-run with `-AgentsRoot` |
| `2` | several different clones | show the table, ask which one, then re-run with `-AgentsRoot` |

Report every note the script prints — a detached HEAD, a dirty tree, a missing upstream, and a nested clone each change what happens at the commit. Use the resolved root for every path afterwards, including the git calls; a globally installed skill path reaches the same files through a junction, but git must run in the clone itself.

## Change it

1. **Name the observed behavior** — quote the evidence from the host repository: what the agent did, which instruction produced it, what it should do instead. An amendment with no such evidence is a preference, and the user decides on preferences.
2. **Edit under `agent-developer`** — it owns which carrier holds the rule and how the rule is written. Format comes from `docs-md-writing`.
3. **Register anything new** — a skill needs its row in `AGENTS.md` and in `skills/README.md`, a role needs its row in the roles table, a new commit scope needs the scope list.
4. **Check** — run `ai-prompt-review`'s `check-references.ps1` and `docs-md-writing`'s `check-markdown.ps1` against the clone, and fix what they report.
5. **Relink a global install** — adding, renaming, or removing a skill directory changes the set of junctions, so re-run `agents-install`'s `install-agents.ps1` and report its table.

## Summarize

Present, before asking for anything:

- every changed file, with the behavior it changes from and to;
- the evidence each change answers;
- what was deliberately left alone, including any amendment considered and rejected;
- `git -C <root> diff --stat`, plus the full diff of the instruction files themselves.

The user reads process changes before they enter history, so the summary is the deliverable even when the commit never follows.

## Commit and push

Only after the user approves the summary in their own words. Approval covers this change; it is not standing permission for the next one.

1. Commit through the `git-commit` skill, in the clone, on its current branch — no flow, no feature branch, no `.progress/`.
2. Push that branch.
3. When the clone is nested in the host repository, its gitlink now points at the new commit. Leave that pointer change uncommitted, and tell the user it is waiting in the host repository.

## Rules

- The host repository's own work is untouched: no phase advances, no host file is edited, and no host commit carries the amendment.
- Stage only the files this amendment changed. A clone that was already dirty keeps its other changes; ask rather than sweep them in.
- Never weaken or delete an existing rule as a side effect of an edit that touches it. That is a separate proposal, with its own approval.
- One amendment is one commit. A second unrelated change is a second summary and a second approval.
