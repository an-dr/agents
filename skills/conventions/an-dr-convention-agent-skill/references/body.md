# Body: title, sections, voice, and commands

## Title and opening

- One `#` heading, first in the body. Actions use a short noun phrase: `# Commit`. Concepts use `# Concept: <name>` and conventions use `# Convention: <name>`.
- The opening paragraph, one to three sentences, says what the skill owns and what it leaves to others, naming each other skill it defers to. A reader can decide from it whether to keep reading.

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

- **Mood by type.** An action is written in the imperative. A concept or convention is written in declarative sentences about what is true of a correct principle or artifact, and contains nothing addressed to the agent as a task.
- **One rule per bullet.** Present tense, one observable rule per bullet, with a reason only where the rule would otherwise seem arbitrary.
- **Current.** The text describes the skill as it works now. History, comparisons with an older design, and "no longer" belong in commit messages.
- **Named rules.** A list of parallel rules leads each with a bold phrase naming the rule: `- **Trace.** A conclusion names its evidence.`
- **One owner.** Another skill is referred to by its exact name in backticks, and each fact has one owner: the text names the owner instead of restating its rule.

## Commands

- A command appears in a fenced `powershell` block, with the skill's own scripts written `<skill>/scripts/<name>.ps1` and another skill's folder as `<that-skill-name>`. Only actions contain commands to run.
- The block is followed by what the command prints or returns and what each exit code means; the action's step also says that the result is relayed to the user.
- A deterministic check lives in a script, and the text says in one sentence what it checks, without restating in prose what the script enforces.
