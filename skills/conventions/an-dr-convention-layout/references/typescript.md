# TypeScript layout

## Project

- `package.json`, its lockfile, `tsconfig.json`, and the test and lint configuration sit at the root.
- The code is in `src/`; compiled output goes to `dist/` or `out/` and is not committed.
- Tests are in `tests/unit/` and `tests/integration/`, with shared helpers in `tests/helpers/`.

## Workspaces

- In an npm workspace, each library package is in `packages/<name>/` with its own `package.json`, `tsconfig.json`, and `src/`.
- Each application is in `apps/<name>/`, laid out as a package.

## Application kinds

- An Electron application splits `src/` by process: `src/main/`, `src/renderer/`, and `src/shared/` for code both use.
- The extension's manifest is its `package.json`, and its entry point is `src/extension.ts`.
- The extension's `manifest.json` sits at the extension's root, beside its `src/`.

## Examples

```text
package.json  package-lock.json  tsconfig.json  vitest.config.ts
src/main/  src/renderer/  src/shared/
tests/unit/  tests/integration/  tests/helpers/
packages/core/       package.json  tsconfig.json  src/
```
