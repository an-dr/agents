---
name: an-dr-ai-use-wip-data
description: Store and read the data of the current operation in tmp-agent-wip.json at the repository root, through one script and a strict register of sections, owners, fields, and readers. Use whenever a skill keeps state between commands, sessions, or machines, or reads another skill's state.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: action
  an-dr.dependencies: none
---

# WIP data

Owns: `tmp-agent-wip.json` and its register, `scripts/sections.json`. No skill reads or writes the file except through `scripts/wip.py`.

## Read and write

```sh
python <skill>/scripts/wip.py get --section <section> --reader <reading-skill> --field <field>
python <skill>/scripts/wip.py get --section <section> --reader <owning-skill>
python <skill>/scripts/wip.py set --section <section> --owner <owning-skill> --json-path <file>
python <skill>/scripts/wip.py remove --section <section> --owner <owning-skill>
python <skill>/scripts/wip.py path
```

- `get` prints compact JSON, `null` when the section or field is absent. The owner may read the whole section; any other reader names one field it is registered for.
- `set` replaces the whole section with the JSON in `--json-path`; only the owner may, and only with registered fields. `remove` deletes the section and the file once it is empty.
- A script calling another skill's script passes this skill's folder as its WIP data skill parameter, and calls `wip.py` in its own process.

## Register a section

- Add the section to `scripts/sections.json` with its `owner`, every field it holds, and per reader skill the fields that skill may read; extend the tests in `scripts/tests/test-wip.py` in the same change.
- One owner per section, named after the skill that writes it; a second writer is a design error, solved by a field the owner writes for it.

## The file

- `{ "schemaVersion": 1, "sections": { "<section>": { … } } }`, written atomically.
- Its name starts with `tmp-`, so it travels with a work branch for another machine to resume and never lands: every `tmp-` file is stripped from a branch's history before it is integrated.
