---
name: adr
description: Record an architecture decision as the next-numbered ADR in docs/adr/. Use in DESIGN when the user settles a genuinely architectural question — not for tactical or tooling choices.
allowed-tools: PowerShell
---

# ADR

Records decisions from the DESIGN phase. Only genuinely architectural calls
get an ADR — decisions with lasting consequences, hard to reverse, or shaping
module boundaries. Tactical and tooling choices don't.

ADRs are immutable: supersede with a new one, never edit an existing one.

## Usage

```powershell
pwsh agents/skills/adr/scripts/adr-new.ps1 -Title '<title>'
```

The script creates `docs/adr/ADR-NNN-<slug>.md` with the next free number and
the section skeleton. Fill in the sections afterwards; every section stays
short.

## Template

```markdown
# ADR-NNN: <title>

## Problem

## Decision

## Rationale

## Rejected alternatives
```
