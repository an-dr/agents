# C layout

An application of several components follows the component layout in [cpp.md](cpp.md).

## Sources

- A library's public headers are in `include/`, inside `include/<name>/` when there is more than one.
- Source files and private headers are in `src/`.
- Optional add-ons shipped with the library, each usable on its own, are in `extensions/<name>/`.

## Build

- `CMakeLists.txt` at the root builds the project; CMake package configuration and helper modules are in `cmake/`.
- A project that also supports Meson has `meson.build` at the root and its helpers in `meson/`.
- Package-manager ports, such as a vcpkg port, are in `ports/<name>/`.
- `.clang-format` at the root defines the formatting.

## Tests and examples

- Unit tests and their framework are in `tests/unit/`.
- Tests that consume the library the way users do, through each supported package manager and build system, are in `tests/integration/<case>/`.
- Each example in `examples/<name>/` builds against the library as a user would.

## Examples

```text
CMakeLists.txt  meson.build  .clang-format  VERSION
include/        microlog.h
src/            microlog.c
extensions/     <add-on>/
cmake/          package config
meson/
ports/microlog/ vcpkg port
tests/unit/     tests/integration/<case>/
examples/<name>/
```
