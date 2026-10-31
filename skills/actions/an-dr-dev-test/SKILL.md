---
name: an-dr-dev-test
description: Verify a code change in Direct or gated VERIFY. Use for relevant tests, boundary and failure cases, regression coverage, and reporting what testing can and cannot establish.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message an-dr-dev-implement-adversarial-ut
---

# Testing

Read test commands and test locations from the host `README.md` and project instructions. Test executable or compilable behavior that changed. A comment, doc comment, or Markdown-only change has no code path for a suite to observe; verify its claims and links through the relevant writing skill instead.

Cover the happy path, boundary values, failure cases, and no-op safety for changed public interfaces. For a bug fix, reproduce the failure with a test first and keep it as the regression anchor. Use `an-dr-dev-implement-adversarial-ut` for a systematic bug hunt. Run a relevant subset while building. In Direct, run the full suite before reporting when code changed. In a gated flow, run only the subset for what the increment touched at each VERIFY; the full suite runs once, after the last known increment.

Do not weaken an assertion, skip a failing test, or treat an unrelated green suite as evidence. Investigate failures and return the change to implementation. Report failure cases, untested edges, documentation gaps, scope, and documentation consistency, using `an-dr-ai-send-message`'s finding levels: failures and gaps first with their level, and passing suites as one count line. Close with the next relevant check or fix — what would resolve the first failure and what it needs — so the report ends on a concrete next step. In Quick and Detailed, the user owns the verification verdict; in Detailed Auto and Direct, the agent records it before moving on.
