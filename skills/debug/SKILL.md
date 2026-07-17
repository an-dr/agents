---
name: debug
description: Root-cause a concrete failure through experiments, not just reading — reproduce, instrument, bisect, and involve the user where the agent cannot run the experiment itself. Use when a bug or unexplained behaviour resists quick code evaluation.
---

# Debug

Find the root cause before proposing any fix. Reading code is the first tool,
not the only one: if evaluation doesn't explain the failure quickly, switch
to experiments — running probes beats theorizing.

## Process

1. **Reproduce first** — a failure that cannot be triggered on demand cannot
   be debugged. Capture the trigger as a failing test where possible.
2. **Evaluate briefly** — read the code path once, form 1–3 concrete
   hypotheses. Time-box this: if the cause isn't clear quickly, stop reading
   and start experimenting.
3. **Experiment** — do practical things that produce evidence:
   - add temporary logs or prints at the suspected boundaries
   - write a probe test that isolates one hypothesis
   - shrink the input until the failure disappears, then grow it back
   - for regressions, bisect: `git bisect start`, `git bisect bad`,
     `git bisect good <ref>`, test each step, `git bisect reset` when done
4. **Involve the user** — where you cannot run the experiment yourself
   (hardware, GUI interaction, external systems, credentials, timing that
   needs a human eye), hand the user one concrete experiment at a time:
   exact steps, and exactly what output or observation to report back.
   Never block on the user for something you can run yourself.
5. **Name the root cause** — one sentence, mechanism not symptom ("X is read
   before Y initializes it", not "X is sometimes wrong").
6. **Propose the minimal fix** — the fix is BUILD work: the smallest change
   that removes the cause. Keep the reproducing test as the regression anchor.

## Rules

- No fix without a named root cause — patching a symptom is a workaround,
  and workarounds get pushed back on (see *Hard rules*, `../../AGENTS.md`).
- One hypothesis per experiment; an experiment that cannot fail proves nothing.
- Remove all temporary instrumentation once the cause is confirmed; logging
  that earns a permanent place goes through BUILD like any other change.
- Do not commit during debugging.
