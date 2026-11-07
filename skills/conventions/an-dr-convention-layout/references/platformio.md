# PlatformIO layout

PlatformIO's own folder rules hold where this file says nothing.

## Project

- `platformio.ini` sits at the project root and declares one `[env:<name>]` per board or build variant; variants are environments of one project, never copies of it.
- The application is in `src/`, and headers shared across it are in `include/`.
- Unit tests are in `test/`, the folder PlatformIO requires.
- Of the `.vscode/` folder PlatformIO generates, only `extensions.json` is committed.

## Libraries

- Each library of the project is in `lib/<name>/`, with its own `src/` and, when it needs build settings, `library.json`.
- Libraries from the PlatformIO registry are declared in `lib_deps`, never copied in.
- Libraries from another repository are git submodules in `lib/<name>/`.
- Logic that does not touch the hardware is in its own library with no framework header, so a `native` environment builds and tests it on the development machine.

## Examples

```text
platformio.ini     [env:uno]  [env:esp32]  [env:native]
src/               main.cpp
include/           pinout.h
lib/control/       src/                  hardware-free logic
lib/microlog/      git submodule
test/              test_control/
```
