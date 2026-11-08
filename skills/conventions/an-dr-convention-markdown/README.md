# an-dr-convention-markdown

Format rules for Markdown files — one line per paragraph, headings, lists, fences, emphasis, links, and aligned tables — with scripts that format and check them.

## When it runs

A convention is read, never run. Every skill that writes or reviews a `.md` file uses it, documentation and `SKILL.md` files included. Commit messages are not Markdown.

## How it works

- **One paragraph, one line.** Prose is never hard-wrapped, so a one-word edit changes one line of the diff.
- **Structure.** One `#` heading, no skipped levels, sentence-case headings, blank lines around blocks, fences that name their language.
- **Inline.** `-` bullets, `**bold**` and `*italic*`, backticks for identifiers and paths, descriptive links with repository-relative paths.
- **Tables** aligned by the formatter, never by hand.

| Script                | Does                                                                  |
| --------------------- | --------------------------------------------------------------------- |
| `format-markdown.ps1` | aligns tables, trims trailing whitespace, ends files with one newline |
| `check-markdown.ps1`  | reports every rule violation and exits non-zero                       |
| `reflow-markdown.ps1` | joins hard-wrapped paragraphs                                         |

## What you get

Markdown that diffs cleanly and reads the same in an editor, on GitHub, and in a terminal.

## Related skills

- [an-dr-convention-readme](../an-dr-convention-readme/README.md) — what a README contains.
- [an-dr-dev-write-documentation](../../actions/an-dr-dev-write-documentation/README.md) — writes the content.
