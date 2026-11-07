---
name: an-dr-convention-markdown
description: Format rules for Markdown files — one line per paragraph, heading levels, lists, fences, emphasis, links, and aligned tables. Use when writing, editing, or reviewing any .md file, including documentation and SKILL.md files; format-markdown.ps1 in this skill formats it and check-markdown.ps1 checks it.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.2.0"
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
- Table columns are aligned, so a table reads as a table in the source as well as when rendered. The formatter below writes the alignment; never pad by hand.
- Every file ends with exactly one newline.

## Check

- `scripts/format-markdown.ps1` brings a file or directory to this format: it aligns tables, removes trailing whitespace, and ends each file with one newline, leaving frontmatter, code fences, and HTML comments untouched. It refuses to write a file whose text would change, and counts an emoji as one character, so a table with emoji can look slightly off in an editor.
- `scripts/check-markdown.ps1` verifies these rules, including hard-wrapped paragraphs and unaligned tables, and exits non-zero on any violation. HTML comments are excluded from prose checks; visible text around them is still checked. `-Path` accepts files or directories.
- `scripts/reflow-markdown.ps1` joins hard-wrapped paragraphs.

Their regression tests are in `scripts/tests/`.
