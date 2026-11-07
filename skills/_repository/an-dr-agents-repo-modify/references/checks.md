# Repository checks

`pwsh <clone>/tests/run-all.ps1`, where `<clone>` is the resolved root.

## Scope

- Default: each changed skill, the skills that declare a dependency on one, and the repository-wide checks.
- `-All`: every suite; CI runs it on each push. Locally only when the change touches `tests/` or the user asks.

## Repository-wide checks

| Script                   | Owner                                 | Checks                                                          |
| ------------------------ | ------------------------------------- | --------------------------------------------------------------- |
| `check-registration.ps1` | `an-dr-convention-agent-skill`        | folders, the skill table, declared dependencies, portable paths |
| `check-skills.ps1`       | `an-dr-convention-agent-skill`        | frontmatter, description, title, section order, reference links |
| `check-skills-ref.ps1`   | `an-dr-convention-agent-skill`        | Agent Skills format through `skills-ref`                        |
| `check-scripts.ps1`      | `an-dr-convention-script`             | script conventions: PowerShell 7, tests, portability            |
| `check-names.ps1`        | `an-dr-agents-repo-convention-skills` | skill names and metadata against the naming rule                |
| `check-references.ps1`   | `an-dr-ai-review-instruction`         | references between instructions resolve                         |
| `check-markdown.ps1`     | `an-dr-convention-markdown`           | Markdown format                                                 |

## Missing `skills-ref`

When the run reports that `skills-ref`, the Agent Skills reference validator, is not installed, recommend its install command and let the user decide; never install it.
