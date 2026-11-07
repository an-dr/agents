# Drafting model

- Spawn a subagent naming a mid-tier model: `sonnet` in Claude Code's subagent call; an explicit spawn model with `model_reasoning_effort: medium` in Codex.
- Steps 1, 2, and 4 stay in the session.
- Host cannot name a model for a subtask → draft in the session; format and checker are the same.

## Pass to the subagent

It cannot see the conversation, so pass:

- the staged diff, or the instruction to run `git diff --staged` itself;
- one sentence of why the change was made, the only body input a diff cannot supply;
- the scope list from the host's root `AGENTS.md`, and the convention `an-dr-convention-commit-message`.

## Return

- Type, scope, summary, and body entries as text.
- It commits nothing; the session runs `new-commit.ps1`, so the history write stays where the user watches.
