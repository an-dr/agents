# Evaluation intent

Preserve these task-specific outcomes and regression boundaries:

- **DS-001.** Finds the newly introduced contradiction: negative values are accepted although the README promises rejection, citing the changed implementation and documentation.
- **DS-002.** Recognizes the wrapper's stated consumer and API constraint; does not recommend removing Adapter merely because it delegates.
- **DS-003.** Treats the performance claim as unsupported by the available evidence, without asserting that it has been disproved.
- **DS-004.** Finds the conflicting API promises with evidence and a concrete clarification proposal.
- **DS-005.** Uses distinct DS IDs for the runtime contradiction and any retained performance question in the initial report.

The discovery cases reuse the first task with implicit and noisy phrasing so activation can be compared separately from execution. The negative case checks that a nearby request does not load the target or create unsolicited artifacts. Existing case IDs and their evidence remain stable.

Run in the declared isolated environment. ZIP fixtures contain complete baseline and working trees; commit the baseline before applying the working tree. Keep expected behavior and assertions private, and record missing capabilities as blocked coverage.
