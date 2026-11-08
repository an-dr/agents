# an-dr-convention-layout

Repository folder layout: the root files and folders every repository shares, plus one layout per project type — Rust, C, C++, STM32 CubeMX, PlatformIO, Python, TypeScript, PowerShell, and multi-discipline hardware.

## When it runs

A convention is read, never run. Skills load it when creating, restructuring, or reviewing a repository's folders, or placing a new file.

## How it works

Shared rules, then the project type's own file on top:

```text
README.md  LICENSE  CHANGELOG.md  CONTRIBUTING.md  AGENTS.md
docs/               index.md, README/ media, adr/, use-cases/, architecture/
examples/<name>/    runnable examples
tests/              unit/ and integration/ when both exist
scripts/            setup, install, release helpers
assets/             files the program loads at run time
vendor/             submodule dependencies
.github/workflows/  CI
```

- Plural folder names; no folder that holds only one subfolder.
- A collection of independent items sits in `<kind>s/<name>/`.
- Build output, caches, and agent output are never committed.
- `CONTRIBUTING.md` holds the build and test commands; `AGENTS.md` points to it and adds only agent-specific facts.

## What you get

Every file has one correct location, and a repository of several types follows each type's layout in its own folder.

## Related skills

- [an-dr-convention-artifact-layout](../an-dr-convention-artifact-layout/README.md) — generated outputs.
- [an-dr-convention-code](../an-dr-convention-code/README.md) — code inside those folders.
