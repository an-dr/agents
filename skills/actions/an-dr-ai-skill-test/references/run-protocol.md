# Run protocol

## Permission

- Script tests and structural checks run in normal development and PR CI.
- Agent evaluations need an explicit user request; editing tests, changing skills, or CI activity authorizes no paid execution.
- CI runs free script and suite checks for PRs touching skills or evaluations; model execution stays out of automatic CI unless the user authorizes a separately bounded run.

## Arms and trials

- Default: the requested revision in one arm.
- Comparison only on user request: with-skill against without-skill for a new skill, old against new for a revision; hold model, fixtures, tools, limits, and host settings constant.
- Single-arm run → labelled diagnostic; no comparative claim.
- Cases declare one trial by default; honor an explicit override; repeated trials when the user asks for reliability evidence.
- Before running, state cases, arms, trials, grader sessions, and total attempt/spending limits.
- Never silently multiply attempts, retry failures, or start paid graders outside the authorized total.

## Best-effort host

When enforced network, filesystem, or skill-discovery isolation is unavailable:

- synthetic inputs, scratch repositories, no live credentials or service actions;
- tested agent's context separated from the rubric and author conversation;
- record actual host capabilities, discoverable skills, and unenforced boundaries;
- grade observed behavior and activation from captured evidence; mark confinement and discovery-dependent conclusions blocked where controls or telemetry are missing;
- fresh sessions, scratch containment, or rubric separation impossible → stop; a normal reply is not a trial.

## Evidence

- Save run manifest, transcripts, tool events, artifacts, diffs, assertion verdicts, invocation evidence, timing, and usage/cost or its explicit unavailability.
- Multiple arms or trials → report per-case deltas and variation; a single success does not establish reliability.
