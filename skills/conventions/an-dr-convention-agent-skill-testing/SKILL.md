---
name: an-dr-convention-agent-skill-testing
description: The contract for skill evaluations, reproducible environments, fixture archives, activation coverage, grading, and deterministic script tests. Use when authoring, executing, packaging, or reviewing tests for an agent skill.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: agent skill testing

Owns: the test contract and layout; authoring and execution procedures consume it without duplicating the schema. A repository convention, not an Agent Skills requirement.

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

- Evaluation suite: every skill, concepts and conventions included, has `evals/evals.json` (the executable contract) and `evals/EVAL.md` (what must never regress and why). Results live outside the suite.
- Script tests: deterministic regression tests are `scripts/tests/test-*.ps1`, reusable inputs in `scripts/tests/fixtures/`, production scripts reached through `$PSScriptRoot/../`. Syntax baselines are identified separately from runtime coverage.
- Local runner: every production `scripts/` folder has a self-contained `scripts/tests/run.ps1`, owned by its skill. It runs all top-level `test-*.ps1` only, each in a fresh non-interactive PowerShell process, preserves diagnostics, and exits non-zero if any fails or none exist. It never discovers nested fixture scripts or invokes models.
- Repository runner: discovers skills through their conventional manifests and invokes only each `scripts/tests/run.ps1`; excludes nested fixtures; fails when no runners are found. Repository validators and evaluation-data checks belong to the owning skill's test suite, never a second list in the root runner.
- After changes to instructions, scripts, or tests, the local runner runs; changed evaluation suites are validated separately. Neither structural validation nor syntax parsing establishes behavioural success.

## Evaluation contract

- [references/eval-contract.md](references/eval-contract.md): suite and case fields, environment, assertion types, and result records.
- [references/fixtures.md](references/fixtures.md): ZIP fixture rules and workspace setup.
- Case IDs and regression evidence are preserved; expected behaviour and assertions stay private from the tested agent.
- Four buckets: explicit invocation, implicit discovery, contextual or noisy discovery, negative near misses (`expected_skill: null`). Concepts and conventions are loaded and applied, not executed.
- Outcomes: realistic prompts and raw evidence; checks on actual artifacts, tool results, and changes; exact wording only when the consumer requires it. Suites start small and gain regression cases for observed failures.
- Environment: declares preferred host, model selector, OS support, required tools, discovery mechanism, loaded instruction set, workspace setup, network, and permissions, preflighted against the actual host. A declaration never grants a capability. Resolved versions and hashes go in the run manifest. Missing isolation controls → best-effort protocol; other unsupported requirements → blocked.
- Isolation: a fresh session and fresh scratch repository per trial and comparison arm; skills installed in the host's normal discovery path when possible; target name hidden from implicit and contextual prompts, only normal discovery metadata exposed; author conversation and grading criteria kept out of the tested session. Network, filesystem, or discovery isolation not enforceable → best-effort protocol, affected coverage reported blocked.
- Fixtures: ZIP files under `evals/fixtures/` with complete `baseline/` and `working/` trees; baseline committed, then the working tree applied including deletions. Never `.git`, credentials, symlinks, executable setup hooks, or live-service dependencies. Validated before extraction, reparse-point ancestors rejected, all writes inside the scratch root.

## Verdicts

- Graders: mechanical checks are tool invocations, artifact existence and content, recorded exit codes, invocation evidence, and diff scope; deterministic graders live in `evals/graders/`. An LLM judge covers only what mechanical checks cannot establish.
- Security baseline: every case also covers secret leakage, unauthorized destructive operations, and access outside the scratch workspace and read-only runtime and skill mounts, with synthetic secrets only. Authorized deletion inside a fixture is permitted.
- Each expectation is pass, fail, or blocked. Any failed behaviour expectation fails the case; otherwise any blocked one blocks it. Security and isolation verdicts are separate, so missing controls do not erase observed behaviour.
- Activation accuracy is separate from behaviour correctness. A positive case that never loads the skill is an activation failure, not evidence its instructions were followed. A negative case passes activation only when the target stays unloaded.

## Check

`scripts/check-evals.ps1` verifies a suite's fields, bucket coverage, assertion contracts, environment declarations, and ZIP contents without extracting fixtures or invoking agents; exits non-zero with a diagnostic on invalid data. Its regression tests exercise the rejection cases.
