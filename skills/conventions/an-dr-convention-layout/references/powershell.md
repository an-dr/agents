# PowerShell layout

## Module

- A module is in `src/<Module>/`, holding `<Module>.psd1` and `<Module>.psm1`, and the folder name equals the module name.
- Each larger function or class is in its own `.ps1` file in the module folder, dot-sourced by the `.psm1`.
- Pester tests are in `tests/`, named `<Subject>.Tests.ps1`.

## Scripts

- A repository of standalone scripts keeps them in `scripts/`, with their tests in `scripts/tests/`.
- A repository that is installed by running a script has `install.ps1` at the root.

## Examples

```text
install.ps1
src/Env/        Env.psd1  Env.psm1  EnvironmentRegistry.ps1
tests/          Env.Tests.ps1
```
