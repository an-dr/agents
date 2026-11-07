---
name: an-dr-convention-layout
description: Repository folder layout - shared root files, docs, tests, no empty nesting, no committed generated files - plus one file per project type - Rust, C, C++, STM32 CubeMX, PlatformIO, Python, TypeScript, PowerShell, hardware. Use when creating, restructuring, or reviewing a repository's folders.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: convention
  an-dr.dependencies: an-dr-convention-artifact-layout
---

# Convention: repository layout

This convention owns the root files and folders every repository has, whatever it builds, and the layout of each project type in its own reference file. A type without one follows its ecosystem's standard layout, such as Gradle's or Flutter's. Generated artifacts follow `an-dr-convention-artifact-layout`.

## Project types

Each file adds one type's layout to the shared rules below; a repository of several types, such as Rust with a TypeScript front end, follows each in its own folders.

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

- **README.** Every repository has `README.md` at the root.
- **License.** Every published repository has `LICENSE` at the root.
- **Tool files.** Build manifests, lockfiles, and formatter, linter, and editor configuration sit at the root, where their tools look for them.
- **Contributor facts.** Build, test, and release commands, the layout, and the repository's rules are in `CONTRIBUTING.md`. `AGENTS.md` points to `CONTRIBUTING.md` and adds only what applies to agents alone; neither names a skill or an agent workflow. `CLAUDE.md`, when present, holds only `@AGENTS.md`.
- **Changelog.** A released project keeps `CHANGELOG.md` at the root.
- **Version file.** A version kept outside the manifest is in a root file named `VERSION`.
- **Optional.** Work notes such as `TODO.md` or `TECHDEBT.md`, and a `<name>.code-workspace`, may sit at the root.

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

- **Plural names.** Folders are `docs/`, `examples/`, and `tests/`. A singular `test/` appears only where the ecosystem's tool requires it, as PlatformIO and Flutter do.
- **No empty nesting.** A folder never holds a single subfolder and nothing else: an application's files sit in `apps/<name>/`, and `apps/<name>/<part>/` exists only when the application has several parts.
- **Collections.** A repository that gathers independent items of one kind holds each in `<kind>s/<name>/`, such as `extensions/<name>/` or `plugins/<name>/`, with the collection's install script at the root.

## Generated files

- **Never committed.** Build output, caches such as `__pycache__/`, and agent output such as code reviews and reports stay out of version control.
- **Agent output.** Reports and reviews live in the ignored `.tmp-ai-gen/` folder that `an-dr-convention-artifact-layout` describes.

## Check

`scripts/check-layout.ps1 [-Path <repository>]` checks a git repository's tracked files against these rules: a missing `README.md` or `LICENSE`, committed generated folders (`.artifacts/`, `code-review/`, `.tmp-ai-gen/`, `__pycache__/`), a top-level `doc/` or `example/`, and an `apps/<name>/` that holds a single subfolder and nothing else. It prints one row per finding, with a missing `LICENSE` as a warning and the rest as errors, and exits `1` on any error.
