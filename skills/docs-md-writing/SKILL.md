---
name: docs-md-writing
description: Format conventions for Markdown files — line breaks, headings, lists, fences, links, and tables — with a checker script. Use whenever writing or editing any .md file, including documentation, role files, and SKILL.md files.
allowed-tools: PowerShell
---

# Markdown writing

Mechanics only. What to document and how to structure it belongs to the `tech-writer` role, or to `agent-developer` when the file is one an agent loads as instruction.

## Line breaks

One paragraph is one line. Never hard-wrap prose to a column.

Wrapping is the renderer's job and the editor's. A hard wrap in the source leaks into previews that honour single newlines, breaks the reader's eye mid-sentence, and turns a one-word edit into a diff across every following line of the paragraph.

Break a line only where the break carries meaning: between list items, between table rows, and between paragraphs. Reflowing a file that is already hard-wrapped is its own separate change, never mixed into an edit about content.

## Rules

- Trailing whitespace is never used. Two trailing spaces are an invisible hard break; use a paragraph break instead.
- One `#` heading per file, and heading levels never skip a level.
- A blank line surrounds every heading, list, table, and code fence.
- Headings are sentence case and carry no trailing punctuation.
- Code fences always name their language.
- Bullets use `-`, ordered items use `1.`, and lists nest only where the content is genuinely hierarchical.
- Emphasis uses `**bold**` and `*italic*`, never underscores.
- Identifiers, paths, commands, and filenames go in backticks. Markdown renders them, so unlike a commit message the backticks never reach the reader.
- Links use descriptive text and repository-relative paths, never "here" and never a bare URL in running prose.
- Table columns are not padded to align. The alignment breaks on the next edit and the churn outlives the benefit.
- Every file ends with exactly one newline.

## Check

```powershell
pwsh agents/skills/docs-md-writing/scripts/check-markdown.ps1 -Path <file-or-directory>
```

The script exits non-zero on a rule violation. Hard-wrapped paragraphs are reported as warnings, because converting an existing file is a deliberate separate change; `-FailOnWrap` promotes them to errors for files that have already been converted.
