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

Owns: `tmp-agent-wip.json` and its register, `scripts/sections.json`. No skill reads or writes the file except through `scripts/wip.ps1`.

## Read and write

```powershell
pwsh <skill>/scripts/wip.ps1 get -Section <section> -Reader <reading-skill> -Field <field>
pwsh <skill>/scripts/wip.ps1 get -Section <section> -Reader <owning-skill>
pwsh <skill>/scripts/wip.ps1 set -Section <section> -Owner <owning-skill> -JsonPath <file>
pwsh <skill>/scripts/wip.ps1 remove -Section <section> -Owner <owning-skill>
pwsh <skill>/scripts/wip.ps1 path
```

- `get` prints compact JSON, `null` when the section or field is absent. The owner may read the whole section; any other reader names one field it is registered for.
- `set` replaces the whole section with the JSON in `-JsonPath`; only the owner may, and only with registered fields. `remove` deletes the section and the file once it is empty.
- A script calling another skill's script passes this skill's folder as `-WipDataSkill`, and calls `wip.ps1` in its own process.

## Register a section

- Add the section to `scripts/sections.json` with its `owner`, every field it holds, and per reader skill the fields that skill may read; extend the tests in `scripts/tests/test-wip.ps1` in the same change.
- One owner per section, named after the skill that writes it; a second writer is a design error, solved by a field the owner writes for it.

## The file

- `{ "schemaVersion": 1, "sections": { "<section>": { … } } }`, written atomically.
- Its name starts with `tmp-`, so it travels with a work branch for another machine to resume and never lands: every `tmp-` file is stripped from a branch's history before it is integrated.
