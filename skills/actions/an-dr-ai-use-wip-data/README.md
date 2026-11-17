# an-dr-ai-use-wip-data

Keeps the data of the work in progress — what each skill needs between commands, sessions, or machines — in one file, `tmp-agent-wip.json`, at the repository root.

## When it runs

- A skill keeps state between commands, sessions, or machines.
- A skill reads another skill's state, within the fields the register allows.

## How it works

One script, `scripts/wip.py`, is the only way in. Its register, `scripts/sections.json`, gives each section one owner skill, the fields it may hold, and the fields each other skill may read. A write by any other skill, a field the register does not list, or a read beyond a reader's fields is refused, so every skill stays strict about what it uses.

## What you get

- `tmp-agent-wip.json` — committed on a work branch so another machine can resume the work, and kept at handover in the branch's one `DO-NOT-MERGE:` commit, which integration drops.
- [an-dr-dev-integrate](../an-dr-dev-integrate/README.md) — reads the base branch from it and drops the commit that holds it before landing.
