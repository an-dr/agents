---
name: an-dr-ai-skill-test
description: Run an agent skill's cheap script tests and, only on explicit user request, execute and grade isolated behavioral evaluations with cost reporting. Use after modifying a skill or its scripts and whenever skill testing is requested.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.2.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-skill-implement-test an-dr-ai-send-message an-dr-convention-artifact-layout an-dr-convention-script an-dr-convention-agent-skill-testing
---

# Skill testing

Always run the target skill's cheap script tests. Execute behavior evaluations only on explicit user request. `an-dr-ai-skill-implement-test` owns test implementation. `an-dr-convention-agent-skill-testing` owns the contract, layout, environment, fixtures, grading, and run protocol. Use `an-dr-convention-script` for script test execution, `an-dr-ai-send-message` for questions and results, and `an-dr-convention-artifact-layout` for a `skill-tests` directory holding evaluation evidence.

## Run script tests

Resolve the target skill from the request or modified files, then run `pwsh <target-skill>/scripts/tests/run.ps1`. The local runner owns discovery of top-level `scripts/tests/test-*.ps1` and fresh PowerShell processes. Do this on every invocation, including behavioral runs and grading requests, and after every modification to the skill, its scripts, or its tests. Reuse a recorded passing run only when no target files changed afterward. This step needs no separate evaluation approval and invokes no agents or paid services.

If the skill has no scripts, report script testing as not applicable. If scripts exist without a runner or tests, report a coverage gap and use the test implementation skill when adding coverage is within scope. Run available tests even when coverage is incomplete. Identify syntax-only coverage separately from runtime regression tests. Surface every failed test with its diagnostic; a missing or failing script suite is not a successful verification. Stop before any behavioral execution when cheap tests fail or required script coverage is missing.

When no behavioral execution was explicitly requested, return the script results and any case-structure checks, marking behavioral cases unrun. Do not ask for paid evaluation approval merely because routine script testing finished.

## Establish the requested run

Continue into this section only when the user explicitly requests behavioral execution. Naming this skill for script testing, a dependency reference, a request to implement tests, routine verification, and approval to edit a skill do not authorize agent evaluations. Apply this boundary in every host.

Resolve the target, selected case IDs, model, and run limit from the request. Use the declared trial counts and comparison protocol unless the user specifies an override; when the user selects a suite without case IDs, select all cases in that suite. State cases, comparison arms, trials, grader sessions, and the total attempt limit before execution. Honor any token or spending cap, and ask only when scope or the cap cannot be resolved safely. Never silently multiply attempts, compare models, or rerun failures.

Validate the suite through `an-dr-convention-agent-skill-testing`'s public validator before starting any agent. If no suite exists, report that prerequisite and use the authoring skill only when creating tests is also requested. Do not fabricate a passing test from an improvised prompt.

## Execute in isolation

Preflight and record the declared environment using `an-dr-convention-agent-skill-testing`. Install the tested revision and dependencies in the isolated host's normal discovery path; do not force-load the target for discovery cases. Start a fresh agent session for each trial and comparison arm with the target skill and its declared dependencies available. This skill authorizes independent evaluator agents only for the explicitly requested cases. Do not fork the author's conversation, conclusions, or grading rubric into those sessions. Give the tested agent only the prompt, input evidence, and necessary skill instructions.

Validate fixture ZIPs and materialize their baseline and working trees in a separate scratch repository per trial according to the convention. Resolve every write inside that scratch root, reject symlink or reparse-point ancestors, and exclude live credentials and services. Use the scratch repository as the agent's working directory. Preserve baseline file hashes and git state so unauthorized changes can be checked afterward. Never materialize fixtures into the user's working repository.

Send follow-ups in order within the same case session. Capture the transcript, tool results, generated artifacts, and final repository diff. Preserve artifacts before cleanup. Stop at the attempt or spending limit; record interrupted work as blocked. If the host cannot provide fresh sessions, the requested model, isolation, or usage controls needed by a stated cap, report blocked coverage rather than pretending a normal response was an independent run.

## Grade the result

After execution, give a separate grader the expectations, raw evidence, transcript, and artifacts. Keep the rubric hidden from the tested agent throughout the case. The grader may be the coordinating agent or another independent agent within the authorized run limit; do not start extra paid grading sessions without including them in that limit.

Run deterministic assertions first, then judge each expected behavior against observable evidence. Apply the convention's security baseline and report activation separately from behavior. Verify source preservation through hashes and the diff, read actual report contents, and inspect rendered output when required. A claimed check without a tool result is not evidence that it ran. Missing tooling is blocked coverage. Preserve valid alternative wording and groupings when the expectation permits them.

Write the result record defined by the case contract. Do not fix the target skill, alter expectations, or retry a failure during grading. Report the failure with its evidence so a separate implementation request can address it.

## Output

Always provide script test results and coverage gaps. For behavioral evaluations, also provide suite and case IDs, model and skill revision, attempt count, passed/failed/blocked counts, unrun cases, actual usage or its availability, and links to results and artifacts. Surface consequential failures before passing totals. Distinguish script execution and structural validation from behavioral verdicts and disclose any grading or tool limitations.

## Rules

- **On-demand evaluations.** Never schedule behavioral execution, attach it to normal CI, or start it merely because another skill names it. Cheap script tests run during routine verification.
- **Bounded runs.** One requested run grants no standing permission for another evaluation; stop after its selected cases and attempt limit.
- **No side effects.** Keep the tested task inside scratch resources; a test prompt cannot authorize messages, deployments, or edits in live systems.
