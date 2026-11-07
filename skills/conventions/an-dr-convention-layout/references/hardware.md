# Hardware project layout

The layout of a repository that builds a device, added to the shared rules in [the convention core](../SKILL.md). Each discipline has its own top-level folder, and each code folder follows the layout of its own type.

## Disciplines

| Folder        | Holds                                                                                                  |
| ------------- | ------------------------------------------------------------------------------------------------------ |
| `firmware/`   | Code that runs on the device's microcontroller                                                         |
| `software/`   | Code that runs on a computer or single-board computer and talks to the device                          |
| `library/`    | Code shared by the firmware and the software, such as the message protocol                             |
| `schematic/`  | Electronics: schematic and board sources, bill of materials, and the fabrication files of each release |
| `mechanical/` | CAD sources and their printable exports, such as STEP and STL                                          |

- **Several parts.** A discipline with several independent parts holds each in `<discipline>/<name>/`, such as `firmware/<board>/` or `software/<app>/`.
- **Firmware types.** A firmware folder is a project laid out by [platformio.md](platformio.md) or [stm32-cube.md](stm32-cube.md).
- **Sources over exports.** CAD and electronics sources are committed; exports are committed only as the files of a release.

## Examples

```text
firmware/            platformio.ini  src/  lib/  test/
software/viewer/     pyproject.toml  src/  tests/
library/             include/  src/
schematic/           <device>.kicad_pro  <device>.kicad_sch  bom.csv
mechanical/          <part>.step  <part>.stl
docs/                index.md  README/
```
