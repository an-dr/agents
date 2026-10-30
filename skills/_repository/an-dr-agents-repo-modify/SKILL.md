---
name: an-dr-agents-repo-modify
description: Change this workflow repository's own instructions — AGENTS.md, roles, skills, and their scripts — from wherever the need appeared, then summarize the change and, once the user approves, commit and push it. Use for every change to this repository, whether the request arises in it or while working in another repository.
license: MIT
allowed-tools: PowerShell Read Grep Glob Write Edit
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-agents-repo-convention-skills an-dr-agents-repo-install an-dr-agents-repo-verify-installation an-dr-ai-review-instruction an-dr-ai-send-message an-dr-ai-skill-implement-test an-dr-ai-skill-test an-dr-ai-write-instruction an-dr-convention-agent-skill an-dr-convention-markdown an-dr-convention-script an-dr-git-commit
---

# Modify the agents repository

The instruction set is used from other repositories, so that is where its defects appear: a rule misfires in a host project, and the fix belongs in the clone rather than in a note that only this conversation remembers. This skill finds that clone from wherever the agent is working, changes it with `an-dr-ai-write-instruction`, and lands it behind one explicit approval.

This skill is how an amendment reaches the clone, whatever proposed it.

## Locate the clone

```powershell
pwsh <skill>/scripts/find-agents-root.ps1 [-Path <start-directory>] [-AgentsRoot <path>]
```

It looks for the clone providing this skill (following the junction of a global install), the repository being worked in, an `agents` submodule inside it, and the policy path in each tool's `an-dr-agents-repo-install` block. It prints a candidate table, then the resolved root's branch, working tree, upstream, and whether it is nested in the host repository.

| Exit | Meaning | Do |
| --- | --- | --- |
| `0` | one clone resolved | work in the printed root |
| `1` | no clone found | ask the user where their clone is through `an-dr-ai-send-message`, then re-run with `-AgentsRoot` |
| `2` | several different clones | show the table and ask which one as an `an-dr-ai-send-message` question with one option per clone, then re-run with `-AgentsRoot` |

Report every note the script prints — a detached HEAD, a dirty tree, a missing upstream, and a nested clone each change what happens at the commit. Use the resolved root for every path afterwards, including the git calls; a globally installed skill path reaches the same files through a junction, but git must run in the clone itself.

## Change it

1. **Name the observed behavior** — quote the evidence, from the host repository or the user's request: what the agent did, which instruction produced it, what it should do instead. An amendment with no such evidence is a preference, and the user decides on preferences.
2. **Edit with `an-dr-ai-write-instruction`** — it owns which carrier holds the rule and how the rule is written. Skill text follows `an-dr-convention-agent-skill`, and format comes from `an-dr-convention-markdown`.
3. **Shape skills with `an-dr-convention-agent-skill` and `an-dr-agents-repo-convention-skills`** — adding, renaming, or restructuring a skill follows the Agent Skills format and its extensions, its category folder and registration, and every name and metadata field follows this repository's naming rule. Its scripts follow `an-dr-convention-script`. A new commit scope needs the scope list in `AGENTS.md`.
4. **Remove redundancy that adds nothing** — across the changed files, and between them and the files they touch, find each rule stated in more than one place. Keep a repeat only when it improves the result: it adds a detail specific to that point, such as the exact options or the safe default, or it puts the rule where an agent would otherwise miss it. Otherwise delete it, or replace it with a reference to its owner by name.
5. **Update what describes the change** — read the root `README.md` and `skills/README.md` against the diff. Wherever they describe behavior the change alters, such as a mode, a phase, a skill, a command, or the layout, update them in the same change. A skill's own documentation going stale is a defect in this step, not a later task.
6. **Maintain and run tests** — use `an-dr-ai-skill-implement-test` for script test coverage and, for new skill behavior or a corrected behavioral failure, behavior cases. After every modification, use `an-dr-ai-skill-test` to run the affected skills' cheap script tests and validate changed case data. Only its behavioral execution requires an explicit user request; changing instructions and running repository checks do not authorize that cost. Report unrun evaluations separately from script results and structural checks.
7. **Check** — run `pwsh <clone>/tests/run-all.ps1`, where `<clone>` is the resolved root, and fix everything it reports. It runs every skill test, `an-dr-convention-agent-skill`'s `check-registration.ps1` (folders, the skill table, declared dependencies, and portable paths), `an-dr-convention-script`'s `check-scripts.ps1`, `an-dr-convention-agent-skill`'s `check-skills.ps1` and `check-skills-ref.ps1`, `an-dr-agents-repo-convention-skills`'s `check-names.ps1`, `an-dr-ai-review-instruction`'s `check-references.ps1`, and `an-dr-convention-markdown`'s `check-markdown.ps1`. When the run reports that `skills-ref`, the Agent Skills reference validator, is not installed, recommend its install command to the user and let them decide; never install it yourself.
8. **Relink a global install** — adding, renaming, or removing a skill directory changes the set of junctions, so re-run `an-dr-agents-repo-install`'s `install-agents.ps1` and report its table.
9. **Verify reachability** — when a skill or policy file was added, renamed, or moved, run `an-dr-agents-repo-verify-installation` to confirm the tools can reach it.

## Summarize

Present, before asking for anything:

- every changed file, with the behavior it changes from and to;
- the evidence each change answers;
- what was deliberately left alone, including any amendment considered and rejected;
- `git -C <root> diff --stat`, plus the full diff of the instruction files themselves.

The user reads process changes before they enter history, so the summary is the deliverable even when the commit never follows.

## Commit and push

Only after the user approves the summary in their own words. Approval covers this change; it is not standing permission for the next one.

1. Commit through the `an-dr-git-commit` skill, in the clone, on its current branch — no flow, no feature branch, no `.progress/`.
2. Push that branch.
3. When the clone is nested in the host repository, its gitlink now points at the new commit. Leave that pointer change uncommitted, and tell the user it is waiting in the host repository.

## Rules

- Explain the intended change and obtain the user's approval as an `an-dr-ai-send-message` confirmation before editing anything. The summary below covers the finished edit; this covers the plan, because a rule the user did not want is cheaper to discuss than to revert.
- The host repository's own work is untouched: no phase advances, no host file is edited, and no host commit carries the amendment.
- Stage only the files this amendment changed. A clone that was already dirty keeps its other changes; ask rather than sweep them in.
- Never weaken or delete an existing rule as a side effect of an edit that touches it. That is a separate proposal, with its own approval.
- One amendment is one commit. A second unrelated change is a second summary and a second approval.
