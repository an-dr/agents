# Evaluation intent

Preserve these task-specific outcomes and regression boundaries:

- **AUTHOR-001.** Creates a structurally valid evals/evals.json suite with stable IDs and observable expectations.
- **AUTHOR-002.** Preserves PARA-001 and its meaning, assigning a new ID to the new scope regression case.
- **AUTHOR-003.** Represents the deleted path in before and uses an empty after map, rather than an empty README file that was not the observed change.
- **AUTHOR-004.** Creates scripts/tests/test-normalize.ps1 that executes the real normalize script and asserts boundary trimming and preservation of interior spaces.

The discovery cases reuse the first task with implicit and noisy phrasing so activation can be compared separately from execution. The negative case checks that a nearby request does not load the target or create unsolicited artifacts. Existing case IDs and their evidence remain stable.

Prefer the declared isolated environment. If only isolation controls are unavailable, use the testing convention's best-effort protocol and report security or discovery limits separately. ZIP fixtures contain complete baseline and working trees; commit the baseline before applying the working tree. Keep expected behavior and assertions private.
