# Evidence

| Look at                                                                         | Tells you                                                         |
| ------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `*.csproj`, `pom.xml` | name, version, entry points, dependencies, library or application |
| `bin/`, `main.*`, `cmd/`, `[project.scripts]`, `"bin"`                          | a CLI, and its command name                                       |
| `packages/`, `apps/`, workspace declarations                                    | a monorepo needing a repository map                               |
| `tests/`, `spec/`, `*_test.*`                                                   | a development section is honest                                   |
| `.github/workflows/`, `.gitlab-ci.yml`                                          | badges can be real; how the project is built                      |
| `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`                              | which of those sections may exist                                 |
| `docs/`, `docs/adr/`                                                            | link out instead of inlining                                      |
| commit count and recency, CI presence                                           | experimental or maintained; the status line is evidence           |
