---
name: an-dr-convention-markdown
description: Format rules for Markdown files — one line per paragraph, heading levels, lists, fences, emphasis, links, and tables. Use when writing, editing, or reviewing any .md file, including documentation and SKILL.md files; check-markdown.ps1 in this skill checks it.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: Markdown

Mechanics only: content and structure belong to whoever writes the document. The scripts below enforce these rules. A commit message is not Markdown and has its own format.

## Line breaks

One paragraph is one line. Never hard-wrap prose to a column.

Wrapping is the renderer's job and the editor's. A hard wrap in the source leaks into previews that honour single newlines, breaks the reader's eye mid-sentence, and turns a one-word edit into a diff across every following line of the paragraph.

Break a line only where the break carries meaning: between list items, between table rows, and between paragraphs. Reflow an existing hard-wrapped paragraph before editing it; never leave a touched paragraph split across source lines.

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
pwsh <skill>/scripts/check-markdown.ps1 -Path <file-or-directory>
```

The script exits non-zero on any rule violation, including a hard-wrapped paragraph. HTML comments are excluded from prose checks; visible text around them is still checked. Run it on every `.md` file you write or touch.

`reflow-markdown.ps1` in the same folder joins hard-wrapped paragraphs. The comment and paragraph regressions live in `tests/test-markdown.ps1`; run them with `pwsh <skill>/scripts/run-tests.ps1`.
