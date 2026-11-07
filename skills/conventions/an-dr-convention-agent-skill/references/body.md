# Body: title, sections, voice, and commands

## Title

- One `#` heading, first in the body. Actions use a short noun phrase: `# Commit`. Concepts use `# Concept: <name>` and conventions use `# Convention: <name>`.
- No intro paragraph. When the skill defers part of its subject to other skills, one line under the title names them: `Owns: X. Defers: Y to `other-skill`.`

## Sections

Sections are `##` headings in sentence case, named for what the reader does or finds there. A skill uses these, in this order, and omits any that do not apply.

| Kind       | Sections                                                                                                                                                                                                                       |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Action     | procedure sections named for their action (`## Select the diff`, `## Capture`), then `## Check` or `## Verify` when the skill verifies its work, then `## Output` for what it hands back, then `## Rules` for invariants, last |
| Concept    | the principle's sections, then `## Violations`, last; how to review against it belongs to an action                                                                                                                            |
| Convention | the rule sections, then `## Check` when a script enforces them, then `## Examples`, last                                                                                                                                       |

- A rule that applies everywhere in the skill goes in `## Rules`; a rule that applies to one step stays beside that step.
- Material that only a branch of the skill needs goes in a reference file, linked from the step that needs it.

## Voice

- Actions: imperative. Concepts and conventions: declarative statements about a correct principle or artifact, nothing addressed to the agent as a task.
- Telegraphic wording, one rule per line; [size.md](size.md) owns the wording and size rules.
- Current behaviour only; history and "no longer" belong in commit messages.
- Another skill is named exactly, in backticks; each fact has one owner, named instead of restated.

## Commands

- A command appears in a fenced `powershell` block, with the skill's own scripts written `<skill>/scripts/<name>.ps1` and another skill's folder as `<that-skill-name>`. Only actions contain commands to run.
- The block is followed by what the command prints or returns and what each exit code means; the action's step also says that the result is relayed to the user.
- A deterministic check lives in a script, and the text says in one sentence what it checks, without restating in prose what the script enforces.
