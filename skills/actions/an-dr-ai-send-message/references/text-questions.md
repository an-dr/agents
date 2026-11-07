# Text-form questions

## Ask

```text
**Q1. Which storage should the cache use?**
  a. SQLite file (Recommended) — survives restarts, one extra dependency
  b. In-memory map — fastest, lost on restart
  c. Redis — shared across processes, needs a running server

**Q2. Which events refresh the cache?** (choose any)
  a. File change
  b. Timer
  c. Manual command

Answer like `1a 2bc`, or write your own text for any question: `2: only on Mondays`.
```

- Questions `Q1`, `Q2`, …; options `a`, `b`, ….
- Keys never change within a round.

## Read

- Accept any order and separator: `1a 2b`, `1a, 2b`, `a b` in question order, `1: a`, `Q2 b`, `1ac` for multi-select, an option's label, `y`/`n` for a confirmation, free text after `N:`.
- A single-question round needs no number.

## Echo

```text
Q1 → a. SQLite file
Q2 → custom: only on Mondays
```
