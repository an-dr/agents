# Python layout

It is the `src` layout of the Python Packaging User Guide.

## Project

- `pyproject.toml` at the root declares the project, its dependencies, its entry points, and its tool configuration. A pinned `requirements.txt` or lockfile, when present, is generated from it.
- The code is in `src/<package>/`, named with the import name in lowercase with underscores. No code sits at the root.
- A command-line program is started through a `[project.scripts]` entry or `src/<package>/__main__.py`.
- The virtual environment is `.venv/` and is not committed.

## Tests

- Tests are in `tests/`, one `test_<module>.py` per module under test.
- pytest and the linter are configured in `pyproject.toml`.

## Service

- A service keeps `Dockerfile`, `.dockerignore`, and `compose.yaml` at the root.
- The service's parts, such as its web applications and its shared core, are subpackages of `src/<package>/`.

## Examples

```text
pyproject.toml  compose.yaml  Dockerfile
src/family_web/      __init__.py  __main__.py  core/  apps/
tests/               test_core.py
```
