# Tests

Run `pwsh tests/run-all.ps1` for free repository checks. It discovers skill manifests and invokes each skill's `scripts/tests/run.ps1`. Each owning suite supplies its repository checks; the testing convention's suite discovers and validates `evals/evals.json` and ZIP fixtures. The root runner carries no validator list. It never invokes a model. A structural pass does not establish behavioral success.

## Deterministic tests

Production helpers live in `scripts/`; their tests live in `scripts/tests/test-*.ps1` and reusable script fixtures in `scripts/tests/fixtures/`. Run one skill with `pwsh <skill>/scripts/tests/run.ps1`. Local runners execute only top-level test scripts in fresh non-interactive PowerShell processes and preserve failures. Syntax baselines are identified separately from runtime regression coverage.

## Skill evaluations

[The testing convention](../skills/conventions/an-dr-convention-agent-skill-testing/SKILL.md) owns the layout, environment, fixture, assertion, grading, and result contracts. [Test implementation](../skills/actions/an-dr-ai-skill-implement-test/SKILL.md) authors coverage; [skill testing](../skills/actions/an-dr-ai-skill-test/SKILL.md) performs checks and explicitly requested agent runs.

Every skill has `evals/evals.json` and `evals/EVAL.md`. Cases cover explicit, implicit, contextual, and negative activation, with behavior outcomes kept private from the tested agent. Repository fixtures are ZIPs under `evals/fixtures/`, containing complete baseline and working snapshots. The harness validates them before extraction, initializes a fresh scratch Git repository, and applies the working snapshot, including deletions.

Validate a suite without starting an agent:

```powershell
pwsh skills/conventions/an-dr-convention-agent-skill-testing/scripts/check-evals.ps1 -Path skills/actions/an-dr-dev-analyze-changes/evals/evals.json
```

To request execution, name the skill, cases, and limits: "Use an-dr-ai-skill-test to run AC-001 once against the change-report skill with the current model, single arm, no extra paid grader." A full repository request covers every suite. The default is one arm and one trial per case, so its tested-agent session count equals the number of cases. Request a comparison or more trials explicitly. The agent states the total before execution and respects any spending cap.

The suite environment is the preferred controlled setup. When the host cannot enforce network, filesystem, or discovery isolation, the best-effort protocol can still collect behavioral evidence in fresh sessions and scratch repositories with synthetic inputs. The run manifest records the actual controls, and unsupported security or activation conclusions are marked blocked separately. Missing fresh sessions, scratch containment, rubric separation, required model, or budget controls still blocks execution. Script results, activation, behavior, security, and usage are reported separately. A one-trial result is a diagnostic, not a reliability estimate.

PR CI runs free checks only. Modifying cases does not authorize paid execution, retries, or comparisons. Existing baseline cases are coverage declarations, not evidence of completed evaluations.
