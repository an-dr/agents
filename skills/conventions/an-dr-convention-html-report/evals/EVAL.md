# Evaluation intent

Preserve these task-specific outcomes and regression boundaries:

- **BASE-001.** Escapes source text and renders diagrams offline rather than executing source markup or requiring a CDN.
- **HTML-002.** Produces the HTML artifact while explicitly marking visual verification blocked and naming the missing browser/image inspection checks.

The discovery cases reuse the first task with implicit and noisy phrasing so activation can be compared separately from execution. The negative case checks that a nearby request does not load the target or create unsolicited artifacts. Existing case IDs and their evidence remain stable.

Prefer the declared isolated environment. If only isolation controls are unavailable, use the testing convention's best-effort protocol and report security or discovery limits separately. ZIP fixtures contain complete baseline and working trees; commit the baseline before applying the working tree. Keep expected behavior and assertions private.
