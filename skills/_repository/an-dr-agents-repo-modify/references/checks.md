# Repository checks

`python <clone>/tests/run-all.py`, where `<clone>` is the resolved root.

## Scope

- Default: each changed skill, the skills that declare a dependency on one, and the repository-wide checks.
- `--all`: every suite; CI runs it on each push. Locally only when the change touches `tests/` or the user asks.

## Repository-wide checks

| Script                  | Owner                                 | Checks                                                          |
| ----------------------- | ------------------------------------- | --------------------------------------------------------------- |
| `check-registration.py` | `an-dr-convention-agent-skill`        | folders, the skill table, declared dependencies, portable paths |
| `check-skills.py`       | `an-dr-convention-agent-skill`        | frontmatter, description, title, section order, reference links |
| `check-skills-ref.py`   | `an-dr-convention-agent-skill`        | Agent Skills format through `skills-ref`                        |
| `check-scripts.py`      | `an-dr-convention-script`             | Python syntax, test runners, portability, leftover PowerShell   |
| `check-names.py`        | `an-dr-agents-repo-convention-skills` | skill names and metadata against the naming rule                |
| `check-references.py`   | `an-dr-ai-review-instruction`         | references between instructions resolve                         |
| `check-markdown.py`     | `an-dr-convention-markdown`           | Markdown format                                                 |

## Missing `skills-ref`

When the run reports that `skills-ref`, the Agent Skills reference validator, is not installed, recommend its install command and let the user decide; never install it.
