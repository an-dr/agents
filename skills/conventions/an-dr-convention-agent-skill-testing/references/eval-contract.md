# Skill evaluation contract

A versioned local JSON contract; the filename follows published practice, the fields are not a universal Agent Skills schema.

## Suite

- Required: `schema_version: 1`, `skill_name`, `environment`, nonempty `evals`. Unknown fields rejected. IDs unique ignoring case. All four buckets present: `explicit`, `implicit`, `contextual`, `negative`.

Environment fields:

- `host`, `model`: nonempty selectors; `current` resolved and recorded at execution
- `os`: nonempty subset of `windows`, `linux`, `macos`
- `tools`: required tool or capability selectors
- `network`: `disabled` or `fixture-only`
- `permissions`: `workspace-only`
- `discovery`: `host-native`
- `instructions`: nonempty instruction selectors
- `workspace`: `fresh-git`

- The environment describes the preferred controlled setup, not a prerequisite that always blocks execution.
- `target-and-dependencies` exposes the tested revision and declared dependencies through normal discovery, without preloading bodies for implicit, contextual, or negative cases; host adapters resolve it without loading the rubric.
- A case override merges with the suite declaration; the resolved object is validated.
- Offline fixtures may emulate service responses; no live account is required.
- Run manifest records: concrete OS, runtime and tool versions, host and model identity, discovery path, instruction contents and hashes, target and dependency hashes, Git state, permissions, network controls, budget enforcement. Inherited host instructions are captured or deliberately excluded, and the choice recorded.
- Missing network, filesystem, or discovery controls → actual exposure recorded, best-effort protocol; confinement or clean discovery never claimed without evidence. Other missing capabilities block execution; machine-wide tools are never installed automatically.

## Cases

- `id`: stable, nonempty.
- `bucket`: one of the four.
- `prompt`: realistic user message; explicit cases name `skill_name`, implicit and contextual ones must not.
- `expected_skill`: the suite skill for positive cases; JSON null for negative.
- `context`: optional nonempty raw evidence; never leaks the answer or rubric.
- `fixtures`: optional nonempty array of suite-relative ZIP paths under `fixtures/`; no overlapping paths across a case's archives.
- `follow_up`: optional nonempty array of user messages, sent in order in the trial's session.
- `environment`: optional partial override.
- `expected_behavior`: nonempty array of independently observable outcomes, hidden from the tested agent.
- `assertions`: nonempty array of typed mechanical checks or judge rubrics, hidden from the tested agent.
- `runs`: positive integer, normally 1; an explicitly requested trial count overrides it and is recorded.
- Input may come entirely from the prompt.

Assertion objects accept only their type's fields:

- `invocation_check`: `expected` boolean vs actual skill-load evidence
- `transcript_check`: `pattern` valid regex, matched only against recorded tool invocations
- `file_check`: `path` safe workspace-relative filename, optional `contains`; missing file fails
- `exit_code`: `command_pattern` regex and integer `expected` vs recorded tool results; missing result is blocked
- `diff_scope`: `allowed_paths` safe relative file or directory prefixes, empty for no writes; hashes, tracked changes, and untracked files compared to the run-start snapshot, input diff kept separately; a prefix permits only that path and descendants
- `deterministic`: `script` safe suite-relative `.ps1` under `graders/`, run with only `-EvidenceRoot` (read-only captured evidence); exit 0 pass, 1 fail, 2 blocked, other exits blocked grader error; non-interactive, inside the sandbox, no model or live account; stdout, stderr, exit captured
- `llm_judge`: `rubric` nonempty text; evidence supplied only after the tested session ends; verdict and evidence recorded per item

- The convention's security baseline applies to every case regardless of assertions; no real secrets in cases; safety is never inferred from missing events.

## Results

- One record per case, comparison arm, and trial: suite and case identity, fixture hashes, revision and dependency hashes, resolved environment, model settings, limits, start and end time, invocation verdict and evidence, transcript, tool, artifact, and diff paths, each behaviour and assertion verdict with evidence, security-baseline verdicts, token usage and cost or explicit unavailability, grader identity and calibration status.
- Pass, fail, blocked, and unrun stay separate; verdict aggregation and the security split follow the convention's Verdicts section.
- Previous attempts are preserved, never overwritten.
- Activation and behaviour aggregate separately, with per-case comparison deltas and repeated-trial variation when available, and disclosed sample size and grader limitations.
