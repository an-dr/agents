# Python layout

The Python layout, added to the shared rules in [the convention core](../SKILL.md). It is the `src` layout of the Python Packaging User Guide.

## Project

- **One declaration.** `pyproject.toml` at the root declares the project, its dependencies, its entry points, and its tool configuration. A pinned `requirements.txt` or lockfile, when present, is generated from it.
- **Package.** The code is in `src/<package>/`, named with the import name in lowercase with underscores. No code sits at the root.
- **Entry point.** A command-line program is started through a `[project.scripts]` entry or `src/<package>/__main__.py`.
- **Environment.** The virtual environment is `.venv/` and is not committed.

## Tests

- **Folder.** Tests are in `tests/`, one `test_<module>.py` per module under test.
- **Configuration.** pytest and the linter are configured in `pyproject.toml`.

## Service

- **Container files.** A service keeps `Dockerfile`, `.dockerignore`, and `compose.yaml` at the root.
- **Parts.** The service's parts, such as its web applications and its shared core, are subpackages of `src/<package>/`.

## Examples

```text
pyproject.toml  compose.yaml  Dockerfile
src/family_web/      __init__.py  __main__.py  core/  apps/
tests/               test_core.py
```
