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

`docs/adr/ADR-NNN-<slug>.md`, numbered contiguously from `001`. An ADR is a deliverable, committed as ordinary repository content.

## Template

```markdown
# ADR-NNN: <title>

## Problem

## Decision

## Rationale

## Rejected alternatives
```

Every section stays short.

## Immutability

An integrated ADR is immutable: a changed decision is a new ADR that supersedes it.

Superseding links both ways, in the same commit. Under its title, the new ADR says which ADR it supersedes, linked to that file. The old ADR gains a single line under its own title, saying which ADR supersedes it, also linked, and no other change. Without that line, a reader who opens the old ADR takes a replaced decision for the current one.

Immutability protects a decision someone else has read. An ADR still on the current feature branch has no such reader, so it is a draft: the branch ships the one decision it reached, edited in place, not a chain of corrections. A second ADR correcting an unintegrated first records the branch's derivation rather than its outcome, and ships a document contradicting the tree beside it. The ADRs a branch adds are numbered contiguously and none of them supersedes, contradicts, or renames another from the same branch.

## Script

`scripts/adr-new.ps1` creates `docs/adr/ADR-NNN-<slug>.md` with the next free number and the section skeleton.
