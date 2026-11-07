---
name: an-dr-convention-adr
description: The format and lifecycle of an architecture decision record — location, numbering, section template, and when an ADR is immutable versus still a draft. Use when writing, editing, superseding, or reviewing an ADR; adr-new.ps1 in this skill creates the file.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: ADR

## Scope

- One genuinely architectural decision per ADR: lasting consequences, hard to reverse, or shaping module boundaries.
- Tactical and tooling choices have no ADR.

## Location and name

- `docs/adr/ADR-NNN-<slug>.md`, numbered contiguously from `001`.
- A deliverable, committed as ordinary repository content.

## Template

```markdown
# ADR-NNN: <title>

## Problem

## Decision

## Rationale

## Rejected alternatives
```

Every section is short.

## Immutability

- An integrated ADR is immutable; a changed decision is a new ADR that supersedes it.
- Superseding links both ways in the same commit: the new ADR states under its title which ADR it supersedes, linked; the old ADR gains one linked line under its title naming its successor and no other change.
- An ADR still on the current feature branch is a draft, since no one else has read it: a later decision on the branch edits it in place.
- The ADRs a branch adds are numbered contiguously; none supersedes, contradicts, or renames another from the same branch.

## Script

- `scripts/adr-new.ps1` creates `docs/adr/ADR-NNN-<slug>.md` with the next free number and the section skeleton.
