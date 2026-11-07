---
name: an-dr-ai-review-instruction
description: Review agentic instructions — AGENTS.md, CLAUDE.md, and SKILL.md files — for contradictions, weakened rules, wasted context, and logic that belongs in a script. Use after editing instructions, before installing them globally, or when an agent keeps behaving in a way the instructions did not intend.
license: MIT
allowed-tools: PowerShell
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message
---

# Agent instruction review

Defers: finding levels to `an-dr-ai-send-message`.

## Review

Subject: every file that reaches an agent's context — `AGENTS.md`, `CLAUDE.md`, every `SKILL.md`, and any prompt or template they load; not the code they produce.

1. Run the reference checker for mechanical faults.
2. Map loading moments: for every rule, name the file that carries it and when that file enters context. A rule nothing loads at the right time does not exist.
3. Read each file as the agent that loads it, in its order; stop at the first place two files disagree.
4. Rank findings by cost: wrong behaviour, then unenforceable rules, then wasted context.

```powershell
pwsh <skill>/scripts/check-references.ps1 [-Path <repo>]
```

Resolves every relative Markdown link, checks every skill `name` against its directory, reports per-file size and approximate token cost; exits non-zero on any broken reference.

## Contradictions

- Same fact stated differently in two files: renamed skill, moved path, a limit of 72 in one and 80 in another.
- Prose disagreeing with a controller, script, or template; the executable wins, the prose is the finding.
- A rule and its exception far enough apart that either reads alone.
- An instruction the harness cannot honour: interactive command in a non-interactive shell, path missing on the target platform.

## Weakened rules

- Hedges making a rule optional: *try to*, *if possible*, *generally*, *where appropriate*, *consider*.
- A rule with no observable outcome.
- Advice with no trigger: taste in a file loaded when nothing acts on it.
- Two rules that can both apply and conflict, with no tiebreak.
- An escape hatch wide enough to swallow the rule, especially *unless you think otherwise*.
- A rule stated once, deep in a long file, competing with everything around it.

## Wasted context

- Length in an always-loaded file; every line of `AGENTS.md` and `CLAUDE.md` is paid on every request.
- A fact restated across files instead of owned by one and referenced.
- Prose doing a table's job; an example repeating the rule.
- A skill description broad enough to trigger when not needed, or narrow enough to miss.
- Long inline output, transcripts, or code a script could produce on demand.
- A file no trigger reaches.

## Logic that belongs in a script

- Signals: numbered procedures with no judgment, formats described in words a checker could assert, invariants stated as reminders, rules whose violation has a mechanical signature.
- Stable steps, known inputs, detectable failure → propose a script that exits non-zero.
- Needs judgment about the specific repository → keep in prose.

## Not findings

- Wording, tone, or ordering that costs nothing.
- A rule that is merely strict.

## Output

- Findings ranked, each with file and line, what breaks, and the concrete edit, shown with its `an-dr-ai-send-message` finding level.
- Areas checked and found sound, as one quiet closing line, so they are not re-reviewed.
