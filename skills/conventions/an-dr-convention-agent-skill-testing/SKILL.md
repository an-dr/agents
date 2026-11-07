---
name: an-dr-convention-agent-skill-testing
description: The contract for skill evaluations, reproducible environments, fixture archives, activation coverage, grading, and deterministic script tests. Use when authoring, executing, packaging, or reviewing tests for an agent skill.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: agent skill testing

Own the test contract and layout for a skill. Authoring and execution procedures consume this convention; keep schema definitions here rather than duplicating them in those procedures. This is a repository convention, not an extension required by the Agent Skills specification.

## Layout

```text
skill/
  SKILL.md
  scripts/
    helper.ps1
    tests/
      run.ps1
      test-helper.ps1
      fixtures/
  evals/
    evals.json
    EVAL.md
    fixtures/
      repository.zip
    graders/
```

- **Evaluation suite.** Every skill, including concepts and conventions, has `evals/evals.json` and `evals/EVAL.md`. The JSON is the executable contract; the Markdown explains what must never regress and why. Results stay outside the suite.
- **Script tests.** Put deterministic regression tests in `scripts/tests/test-*.ps1`, with reusable inputs in `scripts/tests/fixtures/`. Reach production scripts through `$PSScriptRoot/../`. Identify syntax baselines separately from runtime coverage.
- **Local runner.** Every production `scripts/` folder has a self-contained `scripts/tests/run.ps1`. Run only top-level `test-*.ps1` in fresh non-interactive PowerShell processes, run all tests, preserve diagnostics, and exit nonzero if any fails or none exist. Never discover nested fixture scripts or invoke models. Each skill owns its runner.
- **Repository discovery.** A repository-wide runner discovers skills through their conventional manifests and invokes only each skill's `scripts/tests/run.ps1`. Keep repository validators and evaluation-data checks in the owning skill's deterministic test suite; never maintain a second validator list in the root runner. Exclude nested fixtures and fail when no runners are found.
- **After changes.** Run the local runner after changes to instructions, scripts, or tests. Validate changed evaluation suites separately. Neither structural validation nor syntax parsing establishes behavioral success.

## Evaluation contract

Follow [the evaluation contract](references/eval-contract.md) for fields, environment setup, fixture archives, assertion types, and result records. Preserve case IDs and regression evidence. Keep expected behavior and assertions private from the tested agent.

- **Four buckets.** Cover explicit invocation, implicit discovery, contextual or noisy discovery, and negative near misses. Use `expected_skill: null` for negative cases. Concepts and conventions are loaded and applied rather than executed as actions.
- **Observable outcomes.** Use realistic prompts and raw evidence. Check actual artifacts, tool results, and changes; avoid exact answer wording unless the consumer requires it. Start with a small suite and add regression cases for observed failures.
- **Environment.** Declare the preferred host, model selector, OS support, required tools, discovery mechanism, loaded instruction set, workspace setup, network, and permissions. Preflight requirements against the actual host. A declaration never grants a capability. Record resolved versions and hashes in the run manifest; use the best-effort protocol below when only isolation controls are unavailable, and mark other unsupported requirements blocked.
- **Isolation.** Use a fresh session and fresh scratch repository for every trial and comparison arm. Install skills in the host's normal discovery path when possible. Hide the target name from implicit and contextual prompts; expose only normal skill discovery metadata. Keep author conversation and grading criteria out of the tested session. When the host cannot enforce network, filesystem, or discovery isolation, follow the best-effort protocol and report the affected coverage as blocked.
- **Fixtures.** Package repository inputs as ZIP files under `evals/fixtures/`, with complete `baseline/` and `working/` trees. Commit the baseline, then apply the working tree including deletions. Never ship `.git`, credentials, symlinks, executable setup hooks, or live-service dependencies. Validate before extraction, reject reparse-point ancestors, and keep all writes inside the scratch root.

## Verdicts

- **Graders.** Mechanical checks are tool invocations, artifact existence and content, recorded exit codes, invocation evidence, and diff scope. Deterministic grader files live in `evals/graders/`. An LLM judge covers only outcomes mechanical checks cannot establish.
- **Security baseline.** Every case also covers secret leakage, unauthorized destructive operations, and access outside the authorized scratch workspace and read-only runtime and skill mounts, with synthetic secrets only. Authorized deletion inside a fixture is permitted.
- **Verdicts.** Each expectation is pass, fail, or blocked. Any failed behavior expectation makes the behavioral case fail; otherwise any blocked behavior expectation makes it blocked. Security and isolation verdicts are separate, so missing controls do not erase observed behavior.
- **Separate signals.** Activation accuracy is separate from behavior correctness. A positive case that never loads the skill is an activation failure and no evidence that its instructions were followed. A negative case passes activation only when the target remains unloaded.

## Check

`scripts/check-evals.ps1` verifies a suite: fields, bucket coverage, assertion contracts, environment declarations, and ZIP contents, without extracting fixtures or invoking agents. It exits non-zero with a diagnostic on invalid data. Its regression tests exercise the rejection cases.
