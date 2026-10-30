---
name: an-dr-ai-skill-implement-test
description: Implement script tests and reusable behavioral cases for an agent skill, with reproducible fixtures and observable expectations. Use when asked to add or update skill tests, without executing model evaluations.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-write-instruction an-dr-convention-agent-skill an-dr-convention-script
---

# Skill test implementation

Own the design and packaging of script tests and behavior cases. Use `an-dr-ai-write-instruction` for changes to the tested instructions, `an-dr-convention-agent-skill` for skill layout, and `an-dr-convention-script` for executable tests. Implementing tests includes running cheap script tests; it does not authorize running agents or paid evaluators.

## Implement script tests

Read the target skill's scripts and their callers before selecting assertions. Write `tests/test-<script>.ps1` for each script that needs coverage, following the script convention. Exercise observable results, exit codes, boundary inputs, failures, and no-op safety. For a reported defect, capture the failing behavior before changing the implementation. Do not substitute text matching against source code or a mocked copy of the implementation for executing the script.

Keep reusable fixtures in `tests/fixtures/` and isolate generated scratch data from the user's files and live services. Add `scripts/run-tests.ps1` to each script folder; it runs top-level script tests without executing fixtures or behavioral cases. Test scripts must be non-interactive, fail non-zero on an assertion failure, and invoke no model or paid evaluator. Preserve existing tests and assertions when extending coverage. A missing test for a script is a coverage gap to address, not a passing result.

## Select behaviors

Read the target skill and the observed request or failure. Select decisions with observable consequences: a normal result, a boundary or no-op, missing evidence, and relevant scope or side-effect limits. Add adversarial input only when it tests a real boundary of that skill.

Give each case the minimum raw evidence needed to complete the task. Keep the expected answer out of the prompt and context. Grade behavior and artifacts rather than exact wording, heading names, or matches against the skill's prose. Preserve legitimate alternative answers and existing consumer constraints.

## Write cases

Store the suite at `tests/cases.json` inside the target skill. Use the format in [the case contract](references/case-contract.md), which owns the fields and their meaning. Keep prompts and fixtures reproducible and free of live accounts or secrets. Never require a live project to run a case.

Keep existing IDs attached to their cases. Add a regression case for an observed failure without rewriting its evidence to match the current answer. Do not change expected behavior merely to make a failing evaluation pass.

## Check

Run `pwsh <target-skill>/scripts/run-tests.ps1` after every modification to a skill with scripts, including changes to tests or instructions. After a script edit, run its regression tests against the final edited version before reporting it verified. Fix failures within the requested scope or report the failure and remaining coverage explicitly; never replace script execution with case-file validation.

Validate a behavior suite when one was added or changed:

```powershell
pwsh <skill>/scripts/check-test-cases.ps1 -Path <target-skill>/tests/cases.json
```

The script validates the suite format, fixture paths, and case IDs without invoking an agent. It prints the case count on success and exits non-zero with a diagnostic on invalid input; relay that result. Review expectations separately for observable outcomes, unsupported demands, and answer leakage. A valid suite is not a passing behavioral evaluation.

## Output

Deliver script test paths and results, behavior suite paths and coverage, structural check results, and whether any agent evaluations were actually run. Name missing script coverage or a target with no scripts separately. Leave model selection, behavioral execution, grading, and behavioral reruns to an explicit user request. Do not add behavioral execution to ordinary checks or CI.
