---
name: an-dr-dev-debug
description: Root-cause a concrete failure through experiments — reproduce, instrument, bisect, and hand the user experiments the agent cannot run. Use when a bug or unexplained behaviour resists quick code evaluation.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: none
---

# Debug

## Find the root cause

1. Reproduce on demand; capture the trigger as a failing test where possible.
2. Read the code path once; form 1–3 concrete hypotheses. Time-box it: cause not clear quickly → stop reading, experiment.
3. Experiment for evidence:
   - temporary logs at the suspected boundaries;
   - a probe test isolating one hypothesis;
   - shrink the input until the failure disappears, then grow it back;
   - regressions: `git bisect start`, `git bisect bad`, `git bisect good <ref>`, test each step, `git bisect reset`.
4. Experiment needs hardware, GUI interaction, external systems, credentials, or a human eye on timing → hand the user one experiment at a time: exact steps and exactly what to report back. Never wait on the user for what you can run.
5. Name the root cause in one sentence, mechanism not symptom: "X is read before Y initializes it", not "X is sometimes wrong".
6. Propose the minimal fix as BUILD work: the smallest change removing the cause; keep the reproducing test as the regression anchor.

## Rules

- No fix without a named root cause; a symptom patch is a workaround and gets pushed back (Delivery and approval rules, `../../AGENTS.md`).
- One hypothesis per experiment; an experiment that cannot fail proves nothing.
- Remove temporary instrumentation once the cause is confirmed; permanent logging goes through BUILD.
- No commits during debugging.
