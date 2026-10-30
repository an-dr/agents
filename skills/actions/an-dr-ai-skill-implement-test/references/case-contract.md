# Behavioral case contract

The suite is a JSON object with `schema_version: 1` and a nonempty `cases` array. A case has a unique stable `id`, a nonempty `prompt`, a nonempty array of `expectations`, and input evidence in at least one of `context`, `files`, or `before`. Unknown fields are rejected so misspelled fixtures cannot silently disappear.

## Case fields

- `id`: a stable identifier such as `SCOPE-001`, unique within the suite.
- `prompt`: the user request presented to the tested agent, naming the target action when necessary.
- `context`: optional raw task evidence, supplied with the prompt. It must not reveal the grading rubric.
- `files`: an optional object mapping relative paths to UTF-8 text. Materialize these files and commit them as the scratch repository's baseline.
- `before` and `after`: optional file maps used together, with at least one file across the pair. Commit `before` as the baseline, then write `after` as uncommitted changes. Their path sets may differ: remove baseline paths omitted from `after`, and create new paths absent from `before`. Either map may be empty for an addition-only or deletion-only case.
- `unchanged`: an optional nonempty file map committed with `before`. Its paths must not overlap either diff map. Use it for surrounding material that must not be attributed to the change.
- `follow_up`: an optional nonempty array of user messages. Send these in order after each preceding response, using the same session and artifacts.
- `expectations`: nonempty, individually observable pass criteria. Keep these private from the tested agent; reveal them only to the grader after execution.

Use either `files` or the diff maps, never both. A file map contains text strings, including empty strings for empty files. Paths use forward slashes, have no empty, dot, or parent segments, and contain no drive prefix, backslash, colon, or absolute prefix. Reject case-insensitive collisions, file/directory collisions, `.git`, Windows reserved device names, invalid filename characters, and trailing dots or spaces in path segments. Fixtures are ordinary files, never symlinks or commands to run.

## Example

```json
{
  "schema_version": 1,
  "cases": [
    {
      "id": "SCOPE-001",
      "prompt": "Analyze only the uncommitted README change. Propose fixes without editing source.",
      "before": { "README.md": "The limit is 10.\n" },
      "after": { "README.md": "The limit is 20.\n" },
      "unchanged": { "config.json": "{\"limit\": 10}\n" },
      "expectations": [
        "Identifies the mismatch between the changed documentation and configuration with concrete evidence.",
        "Leaves the source and fixture files unchanged."
      ]
    }
  ]
}
```

## Result record

Keep results outside the suite, in the evaluation run's artifacts. Record the case ID, target skill revision or content hash, model, tool availability, execution settings, run time, transcript and artifact paths, and each expectation's verdict and evidence. Record token usage and cost when the host exposes them; otherwise mark them unavailable.

Use `pass`, `fail`, or `blocked` for each expectation. A case fails if any expectation fails; otherwise it is blocked if any expectation is blocked; otherwise it passes. Preserve earlier attempts separately. An unavailable tool, exhausted budget, or unrun case must never become a pass.
