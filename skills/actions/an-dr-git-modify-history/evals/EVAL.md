# Evaluation intent

Preserve these task-specific outcomes and regression boundaries:

- **BASE-001.** Checks recent history and stages only the verified change with the repository's validated message format.
- **MESSAGES-BASE-001.** Preserves commit trees, authors, and dates while limiting the proposed rewrite to messages.

The discovery cases reuse the first task of each section with implicit and noisy phrasing so activation can be compared separately from execution. The negative cases check that a nearby request does not load the target or create unsolicited artifacts. The `MESSAGES-` cases came from the merged message-rewrite skill; their evidence is otherwise unchanged.

Prefer the declared isolated environment. If only isolation controls are unavailable, use the testing convention's best-effort protocol and report security or discovery limits separately. ZIP fixtures contain complete baseline and working trees; commit the baseline before applying the working tree. Keep expected behavior and assertions private.
