---
name: an-dr-ai-skill-implement-test
description: Implement script tests and reusable behavioral cases for an agent skill, with reproducible fixtures and observable expectations. Use when asked to add or update skill tests, without executing model evaluations.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.3.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-write-instruction an-dr-convention-agent-skill an-dr-convention-script an-dr-convention-agent-skill-testing
---

# Skill test implementation

Defers: contract, environment, fixtures, grading assertions, and layout to `an-dr-convention-agent-skill-testing`; tested instructions to `an-dr-ai-write-instruction`; skill layout to `an-dr-convention-agent-skill`; executable tests to `an-dr-convention-script`.

## Implement script tests

1. Read the target skill's scripts and their callers before selecting assertions.
2. Write `scripts/tests/test-<script>.ps1` for each script that needs coverage.
3. Exercise observable results, exit codes, boundary inputs, failures, and no-op safety.
4. For a reported defect, capture the failing behavior before changing the implementation.
5. Execute the script; never substitute text matching against source or a mocked copy of the implementation.
6. Keep reusable fixtures in `scripts/tests/fixtures/`; isolate scratch data from the user's files and live services.
7. Add `scripts/tests/run.ps1` to each skill with scripts; it runs top-level script tests, not fixtures or behavioral cases.
8. Tests are non-interactive, fail non-zero on an assertion failure, and invoke no model or paid evaluator.
9. Preserve existing tests and assertions when extending coverage; a script without a test is a coverage gap, not a pass.

## Select behaviors

- Read the target skill and the observed request or failure.
- Select decisions with observable consequences: a normal result, a boundary or no-op, missing evidence, scope or side-effect limits.
- Adversarial input only when it tests a real boundary of that skill.
- Give each case the minimum raw evidence needed; keep the expected answer out of prompt and context.
- Grade behavior and artifacts, not exact wording, heading names, or matches against the skill's prose.
- Preserve legitimate alternative answers and existing consumer constraints.
- `runs` is one for new cases; repeated trials only when the case needs reliability evidence.

## Write cases

- Store the suite at `evals/evals.json` in the target skill.
- Prompts and fixtures reproducible, free of live accounts and secrets; no case requires a live project.
- Declare the preferred controlled environment; cases also run under the testing convention's best-effort protocol, with security and discovery limitations reported separately.
- Keep existing IDs attached to their cases and their regression evidence.
- Add a regression case for an observed failure without rewriting its evidence to match the current answer.
- Never change expected behavior merely to make a failing evaluation pass.

## Check

1. Run `pwsh <target-skill>/scripts/tests/run.ps1` after every modification to a skill with scripts, including tests or instructions.
2. After a script edit, run its regression tests against the final version before reporting it verified.
3. Fix failures within scope, or report the failure and remaining coverage; never replace script execution with case-file validation.
4. When a behavior suite was added or changed, validate it:

```powershell
pwsh <an-dr-convention-agent-skill-testing>/scripts/check-evals.ps1 -Path <target-skill>/evals/evals.json
```

Validates format, fixture paths, and case IDs without invoking an agent; prints the case count and exits 0 on success, exits non-zero with a diagnostic on invalid input. Relay the result.

5. Review expectations separately for observable outcomes, unsupported demands, and answer leakage; a valid suite is not a passing behavioral evaluation.

## Output

- Script test paths and results, behavior suite paths and coverage, structural check results, and whether any agent evaluations actually ran.
- Missing script coverage or a target with no scripts, named separately.

## Rules

- Running cheap script tests is part of implementing; running agents or paid evaluators is not authorized.
- Model selection, behavioral execution, grading, and reruns only on explicit user request.
- No behavioral execution in ordinary checks or CI.
