---
name: an-dr-convention-markdown
description: Format rules for Markdown files — one line per paragraph, headings, lists, fences, emphasis, links, and aligned tables. Use when writing, editing, or reviewing any .md file, including documentation and SKILL.md files; format-markdown.ps1 in this skill formats it and check-markdown.ps1 checks it.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.3.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: Markdown

Owns: mechanics only. Content and structure belong to the document's writer; a commit message is not Markdown.

## Line breaks

- One paragraph is one line; prose is never hard-wrapped, since a wrap leaks into previews and spreads a one-word edit across the paragraph's diff.
- A line breaks only between list items, table rows, and paragraphs.
- A touched paragraph is never left split across source lines.

## Rules

- No trailing whitespace; two trailing spaces are an invisible hard break, so a paragraph break replaces them.
- One `#` heading per file; heading levels never skip.
- A blank line surrounds every heading, list, table, and code fence.
- Headings are sentence case, without trailing punctuation.
- Code fences name their language.
- Bullets use `-`, ordered items `1.`; lists nest only for genuinely hierarchical content.
- Emphasis uses `**bold**` and `*italic*`, never underscores.
- Identifiers, paths, commands, and filenames are in backticks.
- Links have descriptive text and repository-relative paths; never "here", never a bare URL in prose.
- Table columns are aligned by the formatter, never padded by hand.
- A file ends with exactly one newline.

## Check

- `scripts/format-markdown.ps1` formats a file or directory: aligns tables, removes trailing whitespace, ends each file with one newline; leaves frontmatter, code fences, and HTML comments untouched. It refuses to write a file whose text would change, and counts an emoji as one character, so emoji tables can look slightly off.
- `scripts/check-markdown.ps1` verifies these rules, including hard-wrapped paragraphs and unaligned tables, and exits non-zero on any violation. HTML comments are excluded from prose checks; visible text around them is still checked. `-Path` takes files or directories.
- `scripts/reflow-markdown.ps1` joins hard-wrapped paragraphs.

Regression tests are in `scripts/tests/`.
