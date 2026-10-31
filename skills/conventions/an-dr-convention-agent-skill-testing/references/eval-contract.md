# Skill evaluation contract

This repository uses a versioned local JSON contract. The filename follows published evaluation practice; its fields are not a universal Agent Skills schema.

## Suite

Require `schema_version: 1`, `skill_name`, `environment`, and a nonempty `evals` array. Reject unknown fields. IDs are unique ignoring case. Include all four buckets: `explicit`, `implicit`, `contextual`, and `negative`.

The required environment fields are `host` and `model` (nonempty selectors, with `current` resolved and recorded at execution), `os` (a nonempty subset of `windows`, `linux`, `macos`), `tools` (required tool or capability selectors), `network` (`disabled` or `fixture-only`), `permissions` (`workspace-only`), `discovery` (`host-native`), `instructions` (nonempty instruction selectors), and `workspace` (`fresh-git`). These describe the preferred controlled environment, not a prerequisite that always blocks behavioral execution. `target-and-dependencies` makes the tested revision and its declared dependencies available through normal discovery; it does not preload their bodies for implicit, contextual, or negative cases. Host adapters resolve this without loading the rubric. A case may override environment fields; merge them with the suite declaration and validate the resolved object. Offline fixtures may emulate service responses; no live account is required.

Record concrete OS, runtime/tool versions, host/model identity, discovery path, instruction contents/hashes, target and dependency hashes, Git state, permissions, network controls, and budget enforcement in the run manifest. Capture inherited host instructions or exclude them deliberately and record that choice. If network, filesystem, or discovery controls are missing, record the actual exposure and use the convention's best-effort protocol. Do not claim confinement or uncontaminated discovery without evidence. Other missing capabilities block execution; do not install machine-wide tools automatically.

## Cases

- `id`: stable nonempty identifier.
- `bucket`: one of the four suite buckets.
- `prompt`: realistic user message. Explicit cases name `skill_name`; implicit/contextual cases must not name it.
- `expected_skill`: the suite skill name for positive cases; JSON null for negative cases.
- `context`: optional nonempty raw evidence; it must not leak the answer or rubric.
- `fixtures`: optional nonempty array of suite-relative ZIP paths under `fixtures/`. Archives may not overlap paths across a case's fixtures.
- `follow_up`: optional nonempty array of user messages, sent in order within that trial's session.
- `environment`: optional partial environment override.
- `expected_behavior`: nonempty array of independently observable outcomes, hidden from the tested agent.
- `assertions`: nonempty array of typed mechanical checks or judge rubrics, hidden from the tested agent.
- `runs`: positive integer, normally 1. An explicitly requested trial count overrides this declaration and is recorded.

Input may be supplied entirely by the prompt; additional evidence is optional. Assertion objects accept only the fields belonging to their type:

- `invocation_check`: `expected` boolean, compared with actual skill-load evidence.
- `transcript_check`: `pattern` valid regex, matched only against recorded tool invocations.
- `file_check`: `path` safe workspace-relative filename; optional `contains` text. Missing files fail.
- `exit_code`: `command_pattern` regex and integer `expected`, matched against recorded tool results. Missing results are blocked.
- `diff_scope`: `allowed_paths` array of safe relative file or directory prefixes, empty for no writes. Compare hashes, tracked changes, and untracked files against the run-start working snapshot, preserving the input diff separately; a prefix permits only that path and descendants.
- `deterministic`: `script` safe suite-relative `.ps1` path under `graders/`. Run with a single argument `-EvidenceRoot` pointing at read-only captured evidence; exit 0 means pass, 1 means fail, 2 means blocked. The grader must be non-interactive, remain inside the sandbox, and use no model or live account. Capture stdout, stderr, and exit status; other exits are blocked grader errors.
- `llm_judge`: `rubric` nonempty text. Supply the evidence only after the tested session finishes; record verdict and evidence per item.

Apply the security baseline in the convention to every case regardless of its assertions. Do not put real secrets into a case or infer safety merely from missing events.

## ZIP fixtures

Archives contain only ordinary UTF-8 files beneath `baseline/` and `working/`. Either tree may be absent for addition-only or deletion-only fixtures. Each tree is a complete snapshot, not an overlay. Empty files are valid. ZIP timestamps and compression are not semantic; record the archive SHA-256 at execution.

Reject absolute paths, backslashes, drive prefixes, empty/dot/parent segments, control characters, Windows reserved names, trailing dots/spaces, `.git`, links, encrypted entries, case-insensitive collisions, and file/directory collisions. Reject missing archives, reparse points, and paths outside the suite. Cap each archive at 10,000 entries and 100 MiB total uncompressed data. Validate every entry before creating any file; recheck destination containment and reparse-point ancestors during extraction.

Materialize baseline files, initialize a local Git repository on branch `main` with fixed test identity and hooks disabled, and commit the baseline (allow an empty commit). Apply the complete working tree, deleting baseline paths absent from it, and retain the resulting diff as input evidence. Never reuse a live `.git` directory. Setup is performed by the harness, not by instructions injected into the tested prompt.

## Results

Keep a separate record for every case, comparison arm, and trial. Include suite/case identity, fixture hashes, revision and dependency hashes, resolved environment, model settings, limits, start/end time, invocation verdict/evidence, transcript/tool/artifact/diff paths, each behavior and assertion verdict with evidence, security-baseline verdicts, token usage/cost or explicit unavailability, and grader identity/calibration status.

Keep pass, fail, blocked, and unrun separate. Any failed behavior expectation fails the behavioral case; otherwise any blocked behavior expectation blocks it. Report security and isolation verdicts separately from behavioral verdicts so an unenforced boundary does not erase observed behavior. Preserve previous attempts without overwriting them. Aggregate activation and behavior separately, show per-case comparison deltas and repeated-trial variation when available, and disclose sample size and grader limitations.
