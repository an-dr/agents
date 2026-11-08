---
name: an-dr-dev-test
description: Verify a code change in Vibe or gated VERIFY. Use for relevant tests, boundary and failure cases, regression coverage, and reporting what testing can and cannot establish.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message an-dr-dev-implement-adversarial-ut
---

# Testing

Defers: systematic bug hunts to `an-dr-dev-implement-adversarial-ut`, finding levels to `an-dr-ai-send-message`.

## Select the tests

1. Take test commands and locations from the host `README.md` and project instructions.
2. Test changed executable or compilable behaviour. Comment, doc-comment, or Markdown-only change → no suite; verify claims and links through the relevant writing skill.
3. Cover happy path, boundary values, failure cases, and no-op safety for changed public interfaces.
4. Bug fix → reproduce the failure with a test first; keep it as the regression anchor.

## Choose the scope

- Default, in every flow including each VERIFY and the check after a gated branch's last increment → only affected tests: changed units, their callers, dependent components; the last check covers everything the branch touched.
- Before a release, a change to something everything depends on (build configuration, dependency versions, shared test setup), or user request → full suite.
- CI runs the full suite on every push → that is the periodic full run; say which tests ran locally and leave the rest to CI.

## Output

- Report failure cases, untested edges, documentation gaps, scope, and documentation consistency.
- Failures and gaps first, each with its `an-dr-ai-send-message` finding level; passing suites as one count line.
- End with the next check or fix: what would resolve the first failure and what it needs.
- Supervised → the user owns the verdict. Spec-driven and Vibe → record the verdict before moving on; Vibe also names what the user can run to see it.

## Rules

- Never weaken an assertion, skip a failing test, or treat an unrelated green suite as evidence.
- Investigate failures and return the change to implementation.
