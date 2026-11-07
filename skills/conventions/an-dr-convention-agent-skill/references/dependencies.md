# Dependencies

Dependencies follow `an-dr-concept-clean-dependencies`. Composing skills is intended; coupling to another skill's internals is not.

- **Prefer the agent as the link.** SKILL.md names the other skill, and the agent runs that skill's documented command. No script holds the other skill's path.
- **Name a skill only when the agent needs it to do this skill's work.** A skill exists to be run or read here, not to say who owns something this skill leaves out. An exclusion is stated without naming the skill that does the work.
- **Declare every dependency.** `an-dr.dependencies` lists every skill this skill names, passed folder or not.
- **Mark stable skills.** `PROHIBITED` marks a skill that must never name another skill, such as a concept or a leaf convention. `none` marks a skill with no dependency today that may gain one.
- **Layer.** Dependencies point toward more stable skills: concepts, then conventions, then foundation services. A stable skill never names its consumers.
- **Keep the repository's own skills apart.** A skill outside the underscore folders never depends on one inside them, so every general skill works without the repository's own tooling.
