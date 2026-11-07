# ZIP fixtures

- Contents: only ordinary UTF-8 files beneath `baseline/` and `working/`. Either tree may be absent (addition-only or deletion-only). Each tree is a complete snapshot, not an overlay. Empty files are valid.
- Timestamps and compression are not semantic; the archive SHA-256 is recorded at execution.
- Rejected entries: absolute paths, backslashes, drive prefixes, empty, dot, or parent segments, control characters, Windows reserved names, trailing dots or spaces, `.git`, links, encrypted entries, case-insensitive collisions, file/directory collisions.
- Rejected archives: missing, reparse points, paths outside the suite.
- Caps: 10,000 entries and 100 MiB uncompressed per archive.
- Every entry is validated before any file is created; destination containment and reparse-point ancestors are rechecked during extraction.

## Workspace setup

- Baseline files materialized; local Git repository initialized on `main` with fixed test identity and hooks disabled; baseline committed (empty commit allowed).
- Complete working tree applied, baseline paths absent from it deleted; the resulting diff retained as input evidence.
- A live `.git` directory is never reused.
- The harness performs setup, never instructions injected into the tested prompt.
