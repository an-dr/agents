---
name: docs-writing
description: Write or update human-facing project documentation during Direct work or gated DOCS, including design and architecture prose. Use for content and structure; use convention-markdown for Markdown mechanics. A README rewrite has its own entry skill.
metadata:
  dependencies: agents-ui concept-ai-slop convention-markdown
---

# Documentation writing

Human-facing documentation includes `docs/`, README files, and project guides. Agent-loaded instructions are out of scope. Read the target, its index, and the existing source of authority before editing. Write only what a reader acts on: before delivering, apply `concept-ai-slop`'s cut test to every sentence, section, and example, and remove restatement, padding, decoration, and unverified specifics. A README rewrite has its own entry skill and is not covered here. Write what the system does now: what it is, how to use it, then why it works that way. Register a new document where readers will look for it.

In gated DOCS, document the increment before code exists and leave the change for the increment's commit. In Direct, update needed documentation before the behavior change and deliver both together. Cover what is missing or wrong; leave an already-correct document alone. Changes to public interfaces, architecture, or observable behavior require documentation in the same delivery.

## Place each fact

| Layer | Holds |
| --- | --- |
| Architecture | concepts, boundaries, and guarantees |
| Design | behavior contracts for one subsystem |
| Code doc comments | implementation reasons and local constraints |
| README | orientation and links to deeper material |

An ordinary refactoring should not require a documentation update. Give each specification one home and link to it elsewhere. Use present tense, avoid roadmap history, and do not repeat a table or example in prose. Match the target file's established style.

## Verify

Use `convention-markdown` for format and run its checker on touched Markdown. Resolve every internal link, including references to a moved page. Check claims against the layer above them: architecture against ADRs and the user's intent, design against architecture, and code against design. Check counts and field layouts rather than trusting them. No two documents should state one fact differently.

When an existing behavior contract and code disagree, report the contradiction and evidence for which may be stale. Do not quietly choose either side; ask the user through `agents-ui` when that decision is needed. The written contract normally governs implementation, but abandoned documentation may be stale.
