---
name: an-dr-ai-skill-test
description: Run an agent skill's cheap script tests and, only on explicit user request, execute and grade isolated behavioral evaluations with cost reporting. Use after modifying a skill or its scripts, or whenever skill testing is requested.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.3.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-skill-implement-test an-dr-ai-send-message an-dr-files-build-report an-dr-convention-script an-dr-convention-agent-skill-testing
---

# Skill testing

Owns: executing and grading a run. Defers: test implementation to `an-dr-ai-skill-implement-test`; contract, layout, environment, fixtures, and verdicts to `an-dr-convention-agent-skill-testing`; script test execution to `an-dr-convention-script`; questions and results to `an-dr-ai-send-message`; the `skill-tests` evidence path to `an-dr-files-build-report`.

## Run script tests

Resolve the target skill from the request or modified files, then run:

```powershell
pwsh <target-skill>/scripts/tests/run.ps1
```

- The runner discovers top-level `scripts/tests/test-*.ps1` and runs each in a fresh PowerShell process.
- Run on every invocation, including behavioral runs and grading requests, and after every change to the skill, its scripts, or its tests. Reuse a recorded passing run only when no target file changed since.
- Needs no evaluation approval; starts no agents or paid services.
- No scripts → report script testing not applicable.
- Scripts without runner or tests → report a coverage gap; add coverage through `an-dr-ai-skill-implement-test` only when in scope.
- Run available tests even when coverage is incomplete; report syntax-only coverage separately from runtime regression tests.
- Surface every failed test with its diagnostic; a missing or failing suite is not a successful verification.
- Tests fail or required coverage missing → stop before any behavioral execution.
- No behavioral execution explicitly requested → return script results and case-structure checks, behavioral cases marked unrun. Do not ask for paid evaluation approval because script testing finished.

## Establish the requested run

- Continue only on an explicit user request for behavioral execution. Naming this skill, a dependency reference, a request to implement tests, routine verification, or approval to edit a skill authorize no agent evaluation, in any host.
- Before planning, read [references/run-protocol.md](references/run-protocol.md).
- Resolve target, case IDs, model, and run limit from the request. Suite named without case IDs → all its cases.
- Default: one arm, declared trial counts; other arms or counts only on user request. Full repository run → every suite at one arm, one trial; calculate its attempt count first.
- State cases, arms, trials, grader sessions, and total attempt limit before execution. Honor any token or spending cap; ask only when scope or cap cannot be resolved safely.
- Never silently multiply attempts, compare models, or rerun failures.
- Validate the suite with `an-dr-convention-agent-skill-testing`'s public validator before starting any agent.
- No suite → report the prerequisite; author one only when creating tests is also requested. Never fabricate a passing test from an improvised prompt.

## Execute the requested cases

Before starting sessions, read [references/execution.md](references/execution.md).

## Grade the result

Before grading, read [references/grading.md](references/grading.md).

- Give a separate grader the expectations, raw evidence, transcript, and artifacts; the rubric stays hidden from the tested agent throughout the case.
- The grader is the coordinating agent or another independent agent within the authorized run limit; extra paid grading sessions count toward that limit.
- Deterministic assertions first, then each expected behavior against observable evidence.
- Apply the convention's security baseline; report activation separately from behavior.
- Verify source preservation through hashes and the diff; read actual report contents; inspect rendered output when required.
- A claimed check without a tool result is not evidence; missing tooling is blocked coverage.
- Accept valid alternative wording and groupings the expectation permits.
- Write the result record the case contract defines.
- Never fix the target skill, alter expectations, or retry a failure while grading; report the failure with evidence for a separate implementation request.

## Output

- Always: script test results and coverage gaps.
- Behavioral evaluations add: suite and case IDs, model and skill revision, attempt count, passed/failed/blocked behavior counts, separate security and isolation verdicts, unrun cases, actual usage or its unavailability, links to results and artifacts.
- Consequential failures before passing totals.
- Script execution and structural validation kept distinct from behavioral verdicts; grading and tool limitations disclosed.
- One-trial results labelled diagnostics, not reliability estimates.

## Rules

- Never schedule behavioral execution, attach it to normal CI, or start it because another skill names it; cheap script tests run in routine verification.
- One requested run grants no standing permission; stop after its selected cases and attempt limit.
- The tested task stays inside scratch resources; a test prompt cannot authorize messages, deployments, or edits in live systems.
