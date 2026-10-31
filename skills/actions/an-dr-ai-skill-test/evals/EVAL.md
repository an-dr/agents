# Evaluation intent

Preserve these task-specific outcomes and regression boundaries:

- **RUN-001.** Actually runs target/scripts/tests/test-identity.ps1 and records its passing output before returning routine results.
- **RUN-002.** Validates the suite and runs exactly ISO-001 once in a fresh isolated session without the rubric or coordinating conversation.
- **RUN-003.** Starts no unbounded evaluation under the stated cap.
- **RUN-004.** Grades source preservation as fail from the changed hashes despite the agent's claim.
- **RUN-005.** Runs the real script test, reports its nonzero exit and identity regression diagnostic, and does not mark cheap verification as passed.
- **RUN-006.** Runs both requested cases once each in fresh scratch sessions despite unavailable isolation controls, and reports the resulting security and discovery limits separately.

The discovery cases reuse the first task with implicit and noisy phrasing so activation can be compared separately from execution. The negative case checks that a nearby request does not load the target or create unsolicited artifacts. Existing case IDs and their evidence remain stable.

Prefer the declared isolated environment. If only isolation controls are unavailable, use the testing convention's best-effort protocol and report security or discovery limits separately. ZIP fixtures contain complete baseline and working trees; commit the baseline before applying the working tree. Keep expected behavior and assertions private.
