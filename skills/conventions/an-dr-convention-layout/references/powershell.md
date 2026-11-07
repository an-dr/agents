# PowerShell layout

The PowerShell layout, added to the shared rules in [the convention core](../SKILL.md).

## Module

- **Folder.** A module is in `src/<Module>/`, holding `<Module>.psd1` and `<Module>.psm1`, and the folder name equals the module name.
- **Functions.** Each larger function or class is in its own `.ps1` file in the module folder, dot-sourced by the `.psm1`.
- **Tests.** Pester tests are in `tests/`, named `<Subject>.Tests.ps1`.

## Scripts

- **Collection.** A repository of standalone scripts keeps them in `scripts/`, with their tests in `scripts/tests/`.
- **Install.** A repository that is installed by running a script has `install.ps1` at the root.

## Examples

```text
install.ps1
src/Env/        Env.psd1  Env.psm1  EnvironmentRegistry.ps1
tests/          Env.Tests.ps1
```
