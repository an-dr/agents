# an-dr-ai-use-wip-data

Keeps the data of the work in progress — which flow runs, its stage, the branch it returns to, the handoff for the next session — in one file, `tmp-agent-wip.json`, at the repository root.

## When it runs

- A skill keeps state between commands, sessions, or machines, such as the workflow controller.
- A skill reads another skill's state, such as integration reading the base branch the work started from.

## How it works

One script, `scripts/wip.ps1`, is the only way in. Its register, `scripts/sections.json`, gives each section one owner skill, the fields it may hold, and the fields each other skill may read. A write by any other skill, a field the register does not list, or a read beyond a reader's fields is refused, so every skill stays strict about what it uses.

## What you get

- `tmp-agent-wip.json` — committed on a work branch so another machine can resume the work, and stripped from history when the branch lands, like every `tmp-` file.

## Related

- [an-dr-dev-follow-workflow](../an-dr-dev-follow-workflow/README.md) — owns the `workflow` section.
- [an-dr-dev-integrate](../an-dr-dev-integrate/README.md) — reads the base branch from it and strips the file before landing.
