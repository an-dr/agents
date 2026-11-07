# Evaluation intent

Preserve these task-specific outcomes and regression boundaries:

- **BASE-001.** Names doc/ to become docs/, apps/tool/host/ to move up into apps/tool/, and .artifacts/ to be removed from version control, and does not flag TODO.md. Reports the missing LICENSE for a published repository. Runs or cites check-layout.ps1 for the deterministic rules instead of judging them only by eye.
- **BASE-002 to BASE-005.** Each project-type reference is applied: the Rust workspace with apps/<name>/ unnested and prefixed crates, the STM32 CubeMX split between generated folders and components behind a hardware interface, one PlatformIO project with environments and a framework-free library, and the Python src layout with pyproject.toml.

The discovery cases reuse the first task with implicit and noisy phrasing so activation can be compared separately from execution. The negative case checks that a nearby request does not load the target or create unsolicited artifacts. Existing case IDs and their evidence remain stable.

Prefer the declared isolated environment. If only isolation controls are unavailable, use the testing convention's best-effort protocol and report security or discovery limits separately. Keep expected behavior and assertions private.
