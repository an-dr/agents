# Tests

Run the automated repository checks with `pwsh tests/run-all.ps1`. It discovers each skill's `scripts/run-tests.ps1`, validates case data, and checks packaging. Local runners execute only top-level `tests/test-*.ps1` in fresh PowerShell processes. They preserve failures and never execute nested fixtures or agent evaluations. These checks do not establish that an agent follows a skill.

## Test layout

Every skill has `tests/cases.json`, including passive concepts and conventions. Script tests live in `tests/test-*.ps1`; reusable fixtures live beneath `tests/fixtures/`. Every `scripts/` folder contains its own `run-tests.ps1`, so one skill can be checked with `pwsh <skill>/scripts/run-tests.ps1` without relying on another skill's installed location.

Existing regression suites were moved into this layout. Skills whose scripts have no runtime regression suite have an explicit syntax baseline, `tests/test-script-syntax.ps1`. That baseline parses production scripts and catches syntax errors; it does not exercise runtime behavior. Add regression coverage for changed logic rather than treating a syntax pass as proof of correctness.

## Behavioral tests

[Skill test implementation](../skills/actions/an-dr-ai-skill-implement-test/SKILL.md) owns script test implementation, the behavior case format, and the free structural checker. [Skill testing](../skills/actions/an-dr-ai-skill-test/SKILL.md) always runs cheap script tests and owns isolated behavioral execution and grading. Run script tests after every modification to a skill, its scripts, or its tests. Only agent evaluations need an explicit user request; normal development and the automated suite never start them.

The focused suites include:

- [Change reports](../skills/actions/an-dr-dev-analyze-changes/tests/cases.json)
- [Code and documentation analysis](../skills/actions/an-dr-dev-analyze-slop/tests/cases.json)
- [Text analysis](../skills/actions/an-dr-text-analyze-slop/tests/cases.json)
- [Test authoring](../skills/actions/an-dr-ai-skill-implement-test/tests/cases.json)
- [Script testing and on-demand evaluations](../skills/actions/an-dr-ai-skill-test/tests/cases.json)

`run-all.ps1` checks the structure of these suites without executing their prompts. It also exercises the validator's rejection cases.

The remaining skills have baseline behavior cases in the same location. These describe observable expectations for a representative task; they are not an exhaustive audit or evidence of a successful evaluation.

Each case supplies a user prompt, raw input, and observable expectations. The expectations are a grading rubric, not instructions to give the agent being tested. Matching particular wording is unnecessary.

Check a suite's structure without running an agent:

```powershell
pwsh skills/actions/an-dr-ai-skill-implement-test/scripts/check-test-cases.ps1 -Path skills/actions/an-dr-dev-analyze-changes/tests/cases.json
```

To request execution, name the skill, suite, and desired limits, for example: "Use an-dr-ai-skill-test to run AC-001 once against the change-report skill with the current model." Fresh-session and tool requirements, fixture preparation, result records, and grading follow the execution skill. Parsing a case file is not a passing behavioral evaluation.
