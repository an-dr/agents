---
name: ai-prompt-review
description: Review agentic instructions — AGENTS.md, CLAUDE.md, role files, and SKILL.md files — for contradictions, weakened rules, wasted context, and logic that belongs in a script. Use after editing instructions, before installing them globally, or when an agent keeps behaving in a way the instructions did not intend.
allowed-tools: PowerShell
---

# Agent instruction review

Reviews the instructions themselves, not the code they produce. The subject is every file that reaches an agent's context: `AGENTS.md`, `CLAUDE.md`, `agents/*.md`, `skills/*/SKILL.md`, and any prompt or template they load.

## Method

1. Run the reference checker for the mechanical faults.
2. Map the loading moments — for every rule, name the file that carries it and the moment that file enters context. A rule nothing loads at the right time does not exist.
3. Read each file as the agent that loads it, in its order, and stop at the first place two files disagree.
4. Rank findings by what they cost: wrong behavior first, then unenforceable rules, then wasted context.

```powershell
pwsh agents/skills/ai-prompt-review/scripts/check-references.ps1 [-Path <repo>]
```

The script resolves every `skills/<name>/` and `agents/<name>.md` reference, every relative Markdown link, every `name` against its directory, and every skill and role against the tables that register them. It reports per-file size and an approximate token cost, and exits non-zero on any broken reference.

## Contradictions

- Two files stating the same fact differently. The renamed skill, the moved path, the limit that is 72 in one file and 80 in another.
- Prose that disagrees with a controller, a script, or a template. The executable artifact wins; the prose is the finding.
- A rule and its exception separated far enough that either can be read alone.
- An instruction that the harness cannot honour — an interactive command in a non-interactive shell, a path that does not exist on the target platform.

## Weakened rules

- Hedges that make a rule optional: *try to*, *if possible*, *generally*, *where appropriate*, *consider*. Either the rule holds or it is not a rule.
- A rule with no observable outcome. If no one can tell from the result whether it was followed, it will not be.
- Advice with no trigger. A statement of taste in a file loaded at a moment when nothing acts on it.
- Two rules that can both apply and conflict, with no stated tiebreak.
- An escape hatch wide enough to swallow the rule, especially *unless you think otherwise*.
- A rule stated once, deep inside a long file, competing with everything around it.

## Wasted context

- Length in an always-loaded file. Every line of `AGENTS.md` and `CLAUDE.md` is paid on every request; a line that is not operative is rent.
- A fact restated across files instead of owned by one and referenced.
- Prose doing a table's job, or an example that repeats what the rule already said.
- A skill description broad enough to trigger when it is not needed, or narrow enough to miss when it is.
- Long inline output, transcripts, or code that a script could produce on demand.
- A file no trigger reaches, which costs nothing to run and everything to maintain.

## Logic that belongs in a script

Prose asking for the same deterministic steps every time is a script waiting to be written. Look for numbered procedures with no judgment in them, formats described in words that a checker could assert, invariants stated as reminders, and any rule whose violation has a mechanical signature.

Propose a script when the steps are stable, the inputs are known, and failure is detectable. Keep it in prose when the work needs judgment about the specific repository. A script that exits non-zero converts a rule an agent may forget into a gate it cannot pass.

## Not findings

- The same judgment stated in two role files. Roles are separate readers and each needs its own copy in its own framing; only facts with one correct value need a single owner.
- Wording, tone, or ordering that costs nothing.
- A rule that is merely strict.

## Report

Return findings ranked, each with the file and line, what breaks, and the concrete edit. State separately what was checked and found sound, so a clean area is not re-reviewed later.
