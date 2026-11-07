# C++ layout

The C++ layout, added to the shared rules in [the convention core](../SKILL.md). Components are built with [abcmake](https://github.com/an-dr/abcmake).

## Components

- **One folder each.** Code is split into components in `components/<name>/`, each with its own `CMakeLists.txt`, public headers in `include/<name>/`, and sources and private headers in `src/`.
- **Nested dependencies.** A third-party dependency that only one component uses sits in that component's own `components/` folder; one shared by several sits in the root `components/`.
- **Names.** Component names are lowercase with hyphens and carry the project prefix when the repository publishes them, such as `hyphoria-core`.
- **abcmake.** abcmake is vendored in `cmake/abcmake/`.

## Application

- **Entry point.** An application's own sources, its entry point included, are in `src/`, and the root `CMakeLists.txt` builds them against the components. A library-only repository has no root `src/`.
- **Package manifest.** Dependencies from vcpkg are declared in `vcpkg.json` at the root, and build configurations in `CMakePresets.json`.

## Tests and examples

- **Tests.** Tests are in `tests/unit/` and `tests/integration/`, one folder per component under each.
- **Examples.** Each example is a project in `examples/<name>/` with its own `CMakeLists.txt` and `src/`.

## Tool configuration

`.clang-format`, `.clang-tidy`, `.clangd`, `.cmake-format`, and `CPPLINT.cfg` sit at the root.

## Examples

```text
CMakeLists.txt  CMakePresets.json  vcpkg.json  .clang-format  .clang-tidy
cmake/abcmake/
components/hyphoria-core/  CMakeLists.txt  include/hyphoria/  src/  components/zpp_bits/
src/                       main.cpp
tests/unit/hyphoria-core/
examples/basics/           CMakeLists.txt  src/
```
