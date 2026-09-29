---
name: dev-testing
description: Verify a code change in Direct or gated VERIFY. Use for relevant tests, boundary and failure cases, regression coverage, and reporting what testing can and cannot establish.
---

# Testing

Read test commands and test locations from the host `README.md` and project instructions. Test executable or compilable behavior that changed. A comment, doc comment, or Markdown-only change has no code path for a suite to observe; verify its claims and links through the relevant writing skill instead.

Cover the happy path, boundary values, failure cases, and no-op safety for changed public interfaces. For a bug fix, reproduce the failure with a test first and keep it as the regression anchor. Use `ut-adversarial` for a systematic bug hunt. Run a relevant subset while building, then the full suite before reporting when code changed.

Do not weaken an assertion, skip a failing test, or treat an unrelated green suite as evidence. Investigate failures and return the change to implementation. Report failure cases, untested edges, documentation gaps, scope, and documentation consistency. In Quick and Detailed, the user owns the verification verdict; in Detailed Auto and Direct, the agent records it before moving on.
