---
name: docs-writing
description: Write or update human-facing project documentation during Direct work or gated DOCS, including design and architecture prose. Use for content and structure; use docs-md-writing for Markdown mechanics and docs-readme for a README rewrite.
---

# Documentation writing

Human-facing documentation includes `docs/`, README files, and project guides. Agent-loaded instructions belong to `ai-prompt-writing`. Read the target, its index, and the existing source of authority before editing; for a README rewrite, follow `docs-readme` and read the repository evidence first. Write what the system does now: what it is, how to use it, then why it works that way. Register a new document where readers will look for it.

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

Use `docs-md-writing` for format and run its checker on touched Markdown. Resolve every internal link, including references to a moved page. Check claims against the layer above them: architecture against ADRs and the user's intent, design against architecture, and code against design. Check counts and field layouts rather than trusting them. No two documents should state one fact differently.

When an existing behavior contract and code disagree, report the contradiction and evidence for which may be stale. Do not quietly choose either side; ask the user when that decision is needed. The written contract normally governs implementation, but abandoned documentation may be stale. For a README rewrite, follow `docs-readme` and verify its orientation against the repository evidence.
