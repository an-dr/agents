# Text format

## Safe Markdown

- Use: paragraphs, `#`–`###` headings, bold, inline code, fenced code, bullet and numbered lists one level deep, pipe tables.
- Avoid: HTML tags, deeper nesting, footnotes, task-list checkboxes, Mermaid in chat, meaning-carrying emoji; status glyphs come from the levels below.

## Tables

- Table only when rows share at least two attributes the reader compares; otherwise a list.
- At most 5 columns and about 80 characters per row; long text goes in a numbered note under the table, referenced from the cell: `see 2`.
- First column is a short key the reader can quote back: `1`, `A`, a file name.
- One line per cell: no line breaks or lists; `\|` for a literal pipe; right-align numbers with `---:`.
- Order rows by what the reader acts on first; findings follow the `an-dr-concept-dark-cockpit` ladder.
- Past about 15 rows, show the rows that matter and say how many were left out and where the full list is.

## Findings

Lit rows first, bold only `critical` and `high`, glyph prefix on lit levels, `ok` items last as one line: `ok: 14 checks passed`.

| Level      | Text             |
| ---------- | ---------------- |
| `critical` | `✖ **CRITICAL**` |
| `high`     | `▲ **high**`     |
| `notice`   | `◆ notice`       |
| `info`     | plain            |
| `ok`       | plain, grouped   |
