---
name: docs-adr
description: Record an architecture decision as the next-numbered ADR in docs/adr/. Use in DESIGN when the user settles a genuinely architectural question — not for tactical or tooling choices.
allowed-tools: PowerShell
---

# ADR

Records decisions from the DESIGN phase. Only genuinely architectural calls get an ADR — decisions with lasting consequences, hard to reverse, or shaping module boundaries. Tactical and tooling choices don't.

ADRs are immutable **once integrated**: supersede with a new one, never edit an existing one.

Immutability protects a decision someone else has read. An ADR still on the current feature branch has no such reader, so it is a draft: when the branch later changes its mind, edit that ADR, or collapse several into the one decision that was actually reached. Adding a second ADR to correct a first that has never been integrated records the branch's own derivation rather than its outcome, and it ships a document contradicting the tree beside it.

Before integrating, check the ADRs the branch added — `git diff --diff-filter=A --name-only <base>..HEAD -- docs/adr`. If any of them supersedes, contradicts, or renames something from another in that same list, merge them and renumber so the surviving numbers stay contiguous. Nothing outside the branch references them yet, so renumbering costs only the in-branch links.

## Usage

```powershell
pwsh agents/skills/docs-adr/scripts/adr-new.ps1 -Title '<title>'
```

The script creates `docs/adr/ADR-NNN-<slug>.md` with the next free number and the section skeleton. Fill in the sections afterwards; every section stays short.

## Template

```markdown
# ADR-NNN: <title>

## Problem

## Decision

## Rationale

## Rejected alternatives
```
