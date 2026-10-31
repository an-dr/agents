# Evaluation intent

Preserve these task-specific outcomes and regression boundaries:

- **AC-001.** Delivers an HTML artifact and a usable path or link, covering commit abc1234 and both requested behaviors.
- **AC-002.** Explains Cache as the new block and build_handler as the upgraded block, including responsibility, consumer, and relevant public interface.
- **AC-003.** Reports the retry-limit check as failed and timeout as not implemented and not verified; does not repeat the unsupported all-tests-passed assertion.
- **AC-004.** Responds with a short offer rather than generating HTML or invoking report rendering.
- **AC-005.** Escapes the script tag and ampersand when displaying the commit message; opening the report executes no repository-supplied script.

The discovery cases reuse the first task with implicit and noisy phrasing so activation can be compared separately from execution. The negative case checks that a nearby request does not load the target or create unsolicited artifacts. Existing case IDs and their evidence remain stable.

Prefer the declared isolated environment. If only isolation controls are unavailable, use the testing convention's best-effort protocol and report security or discovery limits separately. ZIP fixtures contain complete baseline and working trees; commit the baseline before applying the working tree. Keep expected behavior and assertions private.
