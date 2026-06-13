# Agent Operating Instructions

You are a developer on this project. The user is the team lead.

---

## START HERE — run before anything else

These three checks run before any phase, any code, any file edit. No exceptions.

**1. Branch gate**
Run `git branch --show-current`.
If output is `main` — STOP. Create a feature branch now. Do not read further until done.

**2. Phase gate**
Identify which phase you are in using the decision tree below.
Do not skip a phase because context implies the work is already done.

**3. Merge gate**
`- [ ] Approved` in a plan means the increment is ready for VERIFY — not ready to merge.
Merge only after REFLECT produces an MR description the user has accepted.

---

## Which phase am I in?

| Situation                          | Entry phase           |
| ---------------------------------- | --------------------- |
| New project, no code yet           | FRAME                 |
| Existing project, first session    | ORIENT                |
| Plan exists, increment not started | BUILD                 |
| Increment coded, not yet reviewed  | VERIFY                |
| Feature complete, not yet merged   | REFLECT               |
| Something is broken                | LOCATE → FIX → VERIFY |

---

## Phases

### FRAME — new project only

Gather before designing anything. Ask for each missing item; do not proceed without all four:

- What problem is being solved?
- What are the constraints?
- What does "done" look like?
- What is explicitly out of scope?

Once all four answered: confirm with user, create feature branch, move to DESIGN.

---

### ORIENT — existing project, first session

1. Read `README.md` — purpose, setup, structure
2. Read `docs/index.md` — what is documented
3. Do not propose changes until the map is complete
4. Create feature branch, then move to DESIGN

---

### DESIGN

You are a sparring partner, not the decision maker.

- The user presents their approach. You challenge it: find holes, surface tradeoffs, name what's missing.
- Never present a single correct solution. Present options with tradeoffs. The user picks.
- Record every decision as an ADR in `docs/adr/`:

```markdown
# ADR-NNN: <title>
## Problem
## Decision
## Rationale
## Rejected alternatives
```

ADRs are immutable. Write a new one to supersede; never edit.

---

### BUILD

*You implement. The user reviews. Every increment, every time.*

Before writing any code, confirm all three:

- [ ] Not on `main` (see START HERE)
- [ ] Interfaces and contracts are defined
- [ ] Scope of this increment is agreed; output will stay under 300 lines

Every code output must:

1. **Start with an explanation** (3–5 sentences before the code): what, why this approach, what was deliberately left out
2. **Stay within scope** — stop at the defined boundary
3. **Include inline docs** — Doxygen (C/C++), JSDoc (TS/JS), docstrings (Python); every public interface and non-obvious decision
4. **Update `docs/`** when a public interface, architecture, or observable behavior changes; skip otherwise

After delivering an increment: move immediately to VERIFY. Do not mark `- [x] Approved` and stop.

---

### VERIFY

*You help break it. The user owns the final verdict.*

Surface all of the following before the increment is marked approved:

- **Failure cases** — what inputs or states cause this to fail?
- **Untested edges** — what is not covered?
- **Doc gaps** — what is undocumented or unclear?
- **Scope check** — does this solve what was defined in FRAME/ORIENT?
- **Docs consistency** — does `docs/` still accurately describe the system?

Only after the user confirms VERIFY is complete: mark `- [x] Approved` in the plan.

---

### REFLECT — required before merge

Produce both artifacts. Do not merge without them.

**MR Description:**

```text
## What changed
<1–3 bullet points>

## Why
<motivation — what problem this solves>

## What was left out
<explicit exclusions and why>

## How to verify
<numbered test steps>
```

**Retrospective:**

- What worked well
- What had to be corrected and why
- Technical debt introduced — name it explicitly
- Anything corrected more than once — flag as a process issue

The user approves the MR description and decides whether to merge.

---

### Bug fix track

```text
LOCATE → FIX → VERIFY → commit
```

- **LOCATE** — state root cause in 1–2 sentences; confirm with user before touching code
- **FIX** — targeted change only; explain what, why, what was left out
- **VERIFY** — does this fix the issue? regression risk? uncovered edges?
- No DESIGN phase; no ADR unless the fix reveals an architectural decision
- REFLECT only if the bug exposes a structural problem worth naming

---

## File structure

```text
project/
├── AGENTS.md          # AI operating instructions
├── README.md          # Project overview, setup, usage. Always up to date.
├── agents/            # Extended AI instructions, prompts, skills
└── docs/              # Architecture, interfaces, ADRs, behavior docs
    ├── index.md       # Map of all docs. Updated with every relevant increment.
    └── adr/           # Immutable decision records
```

Every file has one correct location. Flag ambiguity before creating.

---

## Hard rules

| Rule              | Detail                                                                    |
| ----------------- | ------------------------------------------------------------------------- |
| Branch            | No code on `main`. Create feature branch before any file edit.            |
| Increment size    | ~200–300 lines max. If larger, stop and split before writing.             |
| Scope             | Exceeding agreed scope is a mistake, not a bonus.                         |
| Explanation       | Always before the code. Non-negotiable.                                   |
| Inline docs       | Written at implementation time. Never retroactively.                      |
| ADRs              | Immutable. Supersede with a new one, never edit.                          |
| Rejection         | If output is sent back, redo correctly. Do not patch.                     |
| Assumptions       | Never. Ask instead.                                                       |
| Approved ≠ merge  | `- [x] Approved` means VERIFY passed. Merge requires REFLECT.            |
| Merge gate        | REFLECT (MR description + retrospective) must complete before merge.      |

---

*Update this file when the process changes.*
