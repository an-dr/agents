# Evaluation intent

Preserve these task-specific outcomes and regression boundaries:

- **BASE-001.** Takes the artifact path from the layout script, builds the page with checked exit codes, publishes it as the latest with both paths reported, and marks visual verification blocked when no image inspection is possible instead of inferring it from the renderer.

The discovery cases reuse the first task with implicit and noisy phrasing so activation can be compared separately from execution. The negative case checks that a nearby request does not load the target or create unsolicited artifacts. Existing case IDs and their evidence remain stable.

Prefer the declared isolated environment. If only isolation controls are unavailable, use the testing convention's best-effort protocol and report security or discovery limits separately. Keep expected behavior and assertions private.
