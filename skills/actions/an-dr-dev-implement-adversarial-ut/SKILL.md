---
name: an-dr-dev-implement-adversarial-ut
description: Build a bug-finding unit test suite before fixing anything. Use at the start of a debug or cleanup iteration to capture found bugs as passing tests and a known defect as the failing test its fix must satisfy.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: none
---

# Adversarial unit tests

## Write the tests

Goal: find bugs, not confirm the code works.

1. Functional coverage: standard unit tests per module, happy path and obvious edge cases; get the suite green.
2. Adversarial tests: per module, find an assumption that could be wrong and attack it:
   - boundary values (0, -1, empty string, undefined vs null);
   - special characters in inputs used as regex or path delimiters;
   - races between async operations (A finishes after B);
   - multi-call interactions (call #2 sees state left by call #1);
   - dead code paths (unused constants, settings read but never consumed).
3. Scenario tests: model realistic workflows end to end:
   1. Write a short user story ("user pins a symbol, then switches files").
   2. Derive what the code should do from the function's intent.
   3. Test whether it does.
   4. Flag nonsense: settings that configure nothing, output immediately discarded, guards that fire too late.

## Output

- Bug found during the hunt → test asserts the buggy behaviour, passes, has `BUG:` in its name; it becomes the regression anchor once fixed.
- Known defect whose fix comes next → test asserts the intended contract (an inclusive limit accepts `10`) and fails against current code; the buggy result never becomes the expectation.
- Tests confirming correct behaviour are named normally.
- Record every bug found in the host's `docs/techdebt.md` table (create on first use): ID | Bug description | Source file | Test file.

## Rules

- Do not fix production code; fixes are follow-up increments.
- Do not commit.
