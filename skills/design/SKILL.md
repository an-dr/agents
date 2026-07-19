---
name: design
description: Structure the DESIGN phase for a decision deeper than a quick pick — explore the space with an options table, steelman, and pre-mortem before the user or a Detailed Auto agent decides. Use in a Detailed flow, or when a Quick design question turns out deeper than expected.
---

# Design

Helps the user decide; never decides. Produces the material the DESIGN phase
needs: a small, honest option space with named tradeoffs. The decision is
recorded via the `adr` skill; the resulting design lives in
`docs/design/<topic>.md`.

## Process

1. **Frame the problem** — one paragraph: what is being decided, which
   constraints and existing ADRs bound the space, what "done" looks like.
2. **Build the options table** — 2–4 real options (no strawmen), scored over
   explicit axes (see below).
3. **Steelman the loser** — before recommending, argue the strongest case for
   the option you would reject. If the steelman wins, change the recommendation.
4. **Pre-mortem the favourite** — "this shipped and failed six months later —
   why?" List the top 2–3 failure stories and what would detect each early.
5. **Present** — options with tradeoffs via the option-selection UI; the user
   picks (or explicitly delegates). Never a single "correct" solution.
6. **Record** — the decision goes through the `adr` skill; the resulting
   design goes into the topic's design doc.

## Options table

| Option | Complexity | Reversibility | Blast radius | Effort | Main risk |
| ------ | ---------- | ------------- | ------------ | ------ | --------- |

Reversibility and blast radius weigh most: a cheap, reversible choice needs
little analysis; an expensive one-way door deserves the full treatment.

## Design docs

`docs/design/<topic>.md` (create on first use) — a living document per topic,
lowercase topic name. It opens with a one-line summary linking the ADRs that
decided it, then describes the *current* design (present tense, gaps marked
`TODO`). Rejected options don't live here — they belong in the ADR's
*Rejected alternatives*.

## Rules

- Score axes honestly — no option exists to make the favourite look good.
- An expensive one-way door with a weak pre-mortem is not ready to present;
  keep digging.
- The user owns the decision; delegation must be explicit.
