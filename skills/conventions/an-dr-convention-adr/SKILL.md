---
name: an-dr-convention-adr
description: The format and lifecycle of an architecture decision record — location, numbering, section template, and when an ADR is immutable versus still a draft. Use when writing, editing, superseding, or reviewing an ADR; adr-new.ps1 in this skill creates the file.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: ADR

An ADR records one genuinely architectural decision: lasting consequences, hard to reverse, or shaping module boundaries. Tactical and tooling choices do not get one. `adr-new.ps1` in this skill creates the file with the next free number.

## Location and name

`docs/an-dr-convention-adr/ADR-NNN-<slug>.md`, numbered contiguously from `001`. An ADR is a deliverable, committed as ordinary repository content.

## Template

```markdown
# ADR-NNN: <title>

## Problem

## Decision

## Rationale

## Rejected alternatives
```

Every section stays short.

## Create

```powershell
pwsh <skill>/scripts/adr-new.ps1 -Title '<title>'
```

The script creates `docs/an-dr-convention-adr/ADR-NNN-<slug>.md` with the next free number and the section skeleton. Fill in the sections afterwards.

## Immutability

ADRs are immutable **once integrated**: supersede with a new one, never edit an existing one.

Immutability protects a decision someone else has read. An ADR still on the current feature branch has no such reader, so it is a draft: when the branch later changes its mind, edit that ADR, or collapse several into the one decision that was actually reached. Adding a second ADR to correct a first that has never been integrated records the branch's own derivation rather than its outcome, and it ships a document contradicting the tree beside it.

When ADRs added by one branch supersede, contradict, or rename something from another in that same set, merge them and renumber so the surviving numbers stay contiguous. Nothing outside the branch references them yet, so renumbering costs only the in-branch links. Before integrating, list what the branch added with `git diff --diff-filter=A --name-only <base>..HEAD -- docs/an-dr-convention-adr`.
