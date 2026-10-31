---
name: an-dr-dev-implement-adversarial-ut
description: Build a bug-finding unit test suite before fixing anything. Use at the start of a debug or cleanup iteration to capture found bugs as passing tests and a known defect as the failing test its fix must satisfy.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: action
  an-dr.dependencies: none
---

# Adversarial unit tests

Goal: find bugs, not verify that the code works. A bug found during the hunt is captured as a *passing* test asserting the buggy behaviour, so the suite stays green and the test name doubles as the bug report. A known defect whose fix comes next is captured as the test that fix must satisfy: it asserts the documented or intended behaviour and fails against the current code.

## Process

**Pass 1 — Functional coverage.** Standard unit tests per module: happy path, obvious edge cases. Get the suite running green.

**Pass 2 — Adversarial tests.** For each module, ask "what assumption does this code make that could be wrong?" and attack it:

- Boundary values (0, -1, empty string, undefined vs null)
- Special characters in inputs used as regex or path delimiters
- Race conditions between async operations (what if A finishes after B?)
- Multi-call interactions (does call #2 see state left by call #1?)
- Dead code paths (constants never used, settings read but never consumed)

**Pass 3 — Scenario tests.** Model realistic user workflows end-to-end:

1. Write a short user story ("user pins a symbol, then switches files")
2. Derive what the code *should* do from the function's intent
3. Test whether it actually does that
4. Flag nonsense: settings that configure nothing, output immediately discarded, guards that fire too late

## Output

- A test for a bug found during the hunt asserts the buggy behaviour, passes, and carries `BUG:` in its name; it becomes the regression anchor once the fix lands.
- A regression test for a known defect asserts the intended contract — an inclusive limit accepts `10` — and fails against the current code; the buggy result never becomes the expected limit.
- Tests confirming correct behaviour are named normally.
- Record every bug found in the host's `docs/techdebt.md` table (create on first use): ID | Bug description | Source file | Test file.

## Rules

- Do not fix any production code — fixes are follow-up increments.
- Do not commit.
