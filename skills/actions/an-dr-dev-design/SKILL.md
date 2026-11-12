---
name: an-dr-dev-design
description: Structure a DESIGN decision deeper than a quick pick with an options table, steelman, and pre-mortem before the user decides. Use in a Spec-driven or Supervised DESIGN, or when a Vibe design question turns out deeper than expected.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.2.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-use-user-interface an-dr-convention-adr an-dr-convention-use-case an-dr-dev-write-documentation
---

# Design

Defers: ADR format to `an-dr-convention-adr`, use cases to `an-dr-convention-use-case`, writing to `an-dr-dev-write-documentation`.

## Process

1. Frame in one paragraph: what is decided, which constraints and existing ADRs bound it, which use cases it serves or could break, what done looks like.
2. Build the options table: 2–4 real options, no strawmen.
3. Argue the strongest case for the option you would reject; if it wins, change the recommendation.
4. Pre-mortem the favourite ("shipped, failed six months later — why?"): top 2–3 failure stories and what detects each early.
5. Record each unresolved choice as a controller question first, so exploring the next does not lose it.
6. Present options with tradeoffs as an `an-dr-ai-use-user-interface` question; the user picks. Never a single "correct" solution.
7. Record a lasting decision as an ADR through `an-dr-dev-write-documentation`, close its question with `answer-question`, and put the resulting design in the topic's design doc.

## Options table

| Option | Complexity | Reversibility | Blast radius | Effort | Main risk |
| ------ | ---------- | ------------- | ------------ | ------ | --------- |

Reversibility and blast radius weigh most: a cheap reversible choice needs little analysis, an expensive one-way door the full treatment.

## Design docs

- `docs/design/<topic>.md`, lowercase topic, created on first use; one living document per topic.
- Opens with a one-line summary linking the deciding ADRs, then the current design in present tense, gaps marked `TODO`.
- Rejected options go in the ADR's *Rejected alternatives*, not here.

## Rules

- Score axes honestly; no option exists to flatter the favourite.
- An expensive one-way door with a weak pre-mortem is not ready to present.
- The user owns the decision in every flow; Spec-driven delegates the work after DESIGN, not the design.
