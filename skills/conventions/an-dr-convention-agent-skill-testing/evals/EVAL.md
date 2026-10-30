# Evaluation intent

Preserve these task-specific outcomes and regression boundaries:

- **TESTING-001.** Places evaluations in evals/evals.json and deterministic tests under scripts/tests/ with run.ps1.

TESTING-002 preserves repository-runner discovery: adding a conforming suite must not require edits to a root list, and fixture programs must remain inert.

The discovery cases reuse the first task with implicit and noisy phrasing so activation can be compared separately from execution. The negative case checks that a nearby request does not load the target or create unsolicited artifacts. Existing case IDs and their evidence remain stable.

Run in the declared isolated environment. ZIP fixtures contain complete baseline and working trees; commit the baseline before applying the working tree. Keep expected behavior and assertions private, and record missing capabilities as blocked coverage.
