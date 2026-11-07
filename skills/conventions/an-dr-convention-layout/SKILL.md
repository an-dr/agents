---
name: an-dr-convention-layout
description: Repository folder layout - shared root files, docs, tests, no empty nesting, no committed generated files - plus one file per project type - Rust, C, C++, STM32 CubeMX, PlatformIO, Python, TypeScript, PowerShell, hardware. Use when creating, restructuring, or reviewing a repository's folders.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: convention
  an-dr.dependencies: an-dr-convention-artifact-layout
---

# Convention: repository layout

Owns: root files and folders of every repository, and each project type's layout. Defers: generated artifacts to `an-dr-convention-artifact-layout`.

## Project types

Each file adds one type's layout to the shared rules below. A repository of several types (Rust with a TypeScript front end) follows each in its own folders. A type without a file follows its ecosystem's standard layout (Gradle, Flutter).

- [references/rust.md](references/rust.md): Rust crate or workspace
- [references/c.md](references/c.md): C library or application
- [references/cpp.md](references/cpp.md): C++ with CMake and abcmake
- [references/stm32-cube.md](references/stm32-cube.md): STM32 firmware from CubeMX with CMake
- [references/platformio.md](references/platformio.md): PlatformIO firmware
- [references/python.md](references/python.md): Python
- [references/typescript.md](references/typescript.md): TypeScript or JavaScript
- [references/powershell.md](references/powershell.md): PowerShell module or scripts
- [references/hardware.md](references/hardware.md): hardware device with several disciplines

## Root files

- `README.md` in every repository.
- `LICENSE` in every published repository.
- Build manifests, lockfiles, and formatter, linter, and editor configuration sit at the root, where their tools look.
- `CONTRIBUTING.md` holds build, test, and release commands, the layout, and the repository's rules. `AGENTS.md` points to it and adds only agent-specific facts; neither names a skill or agent workflow. `CLAUDE.md`, when present, holds only `@AGENTS.md`.
- `CHANGELOG.md` in a released project.
- `VERSION` holds a version kept outside the manifest.
- Optional: work notes (`TODO.md`, `TECHDEBT.md`) and a `<name>.code-workspace`.

## Folders

| Folder               | Holds                                                                                       |
| -------------------- | ------------------------------------------------------------------------------------------- |
| `docs/`              | Human documentation, entered through `docs/index.md`                                        |
| `docs/README/`       | Images and media the README shows                                                           |
| `docs/adr/`          | Architecture decision records                                                               |
| `docs/use-cases/`    | Use cases                                                                                   |
| `docs/architecture/` | Architecture and design prose too large for `docs/index.md`                                 |
| `examples/`          | Runnable examples, one folder each                                                          |
| `tests/`             | Tests outside the source tree; `tests/unit/` and `tests/integration/` when both kinds exist |
| `scripts/`           | Helper scripts for setting up, installing, and releasing                                    |
| `assets/`            | Files the program loads at run time: images, sounds, fonts, data                            |
| `vendor/`            | Dependencies kept as git submodules                                                         |
| `.github/workflows/` | CI                                                                                          |

- Folder names are plural (`docs/`, `examples/`, `tests/`); singular `test/` only where the tool requires it (PlatformIO, Flutter).
- No folder holds a single subfolder and nothing else: an application's files sit in `apps/<name>/`; `apps/<name>/<part>/` exists only with several parts.
- A collection of independent items of one kind holds each in `<kind>s/<name>/` (`extensions/<name>/`, `plugins/<name>/`), with the collection's install script at the root.

## Generated files

- Build output, caches (`__pycache__/`), and agent output (code reviews, reports) are never committed.
- Agent reports and reviews live in the ignored `.tmp-ai-gen/` folder of `an-dr-convention-artifact-layout`.

## Check

`scripts/check-layout.ps1 [-Path <repository>]` checks a git repository's tracked files for: missing `README.md` or `LICENSE`, committed generated folders (`.artifacts/`, `code-review/`, `.tmp-ai-gen/`, `__pycache__/`), top-level `doc/` or `example/`, and an `apps/<name>/` holding only a single subfolder. One row per finding, missing `LICENSE` a warning and the rest errors; exits `1` on any error.
