---
name: an-dr-dev-write-documentation
description: Write or update human-facing project documentation, including design and architecture prose, during Vibe work or gated DOCS. Use for documentation content and structure; Markdown mechanics and README rewrites have their own skills.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.2.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-use-user-interface an-dr-concept-ai-slop an-dr-convention-adr an-dr-convention-markdown an-dr-convention-use-case
---

# Documentation writing

Defers: Markdown format to `an-dr-convention-markdown`, use cases to `an-dr-convention-use-case`, ADR format to `an-dr-convention-adr`, README rewrites to their own entry skill.

## Scope

- In scope: `docs/`, README files, project guides. Out: agent-loaded instructions.
- Gated DOCS → document the increment before code exists; leave the change for the increment's commit.
- Vibe → update documentation before the behaviour change; deliver both together.
- Public interface, architecture, or observable behaviour changed → document in the same delivery; with `docs/use-cases/`, update the capability's use case.
- Ordinary refactoring → no documentation update.
- Already-correct document → leave it alone.

## Write

1. Read the target, its index, and the existing source of authority.
2. Place each fact in its layer (table below); one home per specification, linked elsewhere.
3. Write what the system does now: what it is, how to use it, then why. Present tense, no roadmap history, match the file's established style.
4. Apply `an-dr-concept-ai-slop`'s cut test to every sentence, section, and example; remove restatement, padding, decoration, unverified specifics, and prose repeating a table or example.
5. Register a new document where readers look for it.
6. Lasting architectural decision → ADR; first read [references/adr.md](references/adr.md).

| Layer             | Holds                                                                                               |
| ----------------- | --------------------------------------------------------------------------------------------------- |
| Use cases         | who reaches which goal, and what they observe: what must keep working (`an-dr-convention-use-case`) |
| Architecture      | concepts, boundaries, and guarantees                                                                |
| Design            | behaviour contracts for one subsystem                                                               |
| Code doc comments | implementation reasons and local constraints                                                        |
| README            | orientation and links to deeper material                                                            |

## Verify

Format and check every `.md` file written or touched:

```powershell
pwsh <an-dr-convention-markdown>/scripts/format-markdown.ps1 -Path <file-or-directory>
pwsh <an-dr-convention-markdown>/scripts/check-markdown.ps1 -Path <file-or-directory>
```

The formatter prints each file it changed; the checker exits non-zero on a violation. Fix what it reports and relay the result.

- Resolve every internal link, including references to moved pages.
- Check claims against the layer above: architecture against ADRs and user intent, design against architecture, code against design.
- Check counts and field layouts; no two documents state one fact differently.
- Behaviour contract and code disagree → report the contradiction with evidence of which may be stale; never silently pick a side; ask the user through `an-dr-ai-use-user-interface` when the decision is needed. The written contract normally governs, but abandoned documentation may be stale.
