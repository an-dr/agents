"""Define what an aligned Markdown table is.

The formatter writes this form and the checker compares against it, so the two
cannot disagree. Import it.
"""

from __future__ import annotations

import re
import unicodedata


SEPARATOR = re.compile(r":?-+:?")
UNESCAPED_PIPE = re.compile(r"(?<!\\)\|")


def cells(row: str) -> list[str]:
    """Split a table row into trimmed cells; an escaped pipe stays inside its cell."""
    body = re.sub(r"^\|", "", row.strip())
    body = re.sub(r"(?<!\\)\|$", "", body)
    return [cell.strip() for cell in UNESCAPED_PIPE.split(body)]


def _extends(character: str) -> bool:
    """Report whether the code point continues the preceding grapheme cluster."""
    code = ord(character)
    return (
        unicodedata.category(character) in ("Mn", "Mc", "Me")
        or 0x1F3FB <= code <= 0x1F3FF
        or 0xE0020 <= code <= 0xE007F
        or character == "\u200c"
    )


def cell_width(text: str) -> int:
    """Count visible characters, so a combined character or an emoji counts once."""
    count = 0
    regional = 0
    previous_zwj = False
    for character in text:
        is_regional = 0x1F1E6 <= ord(character) <= 0x1F1FF
        if count == 0:
            count = 1
            regional = 1 if is_regional else 0
        elif previous_zwj or _extends(character) or character == "\u200d" or (is_regional and regional == 1):
            if is_regional:
                regional = 2
        else:
            count += 1
            regional = 1 if is_regional else 0
        previous_zwj = character == "\u200d"
    return count


def format_markdown_table(rows: list[str]) -> list[str]:
    """Return one table block with its columns aligned; other pipe-only blocks return unchanged."""
    if len(rows) < 2:
        return rows
    separator = cells(rows[1])
    if not all(SEPARATOR.fullmatch(cell) for cell in separator):
        return rows

    indent = re.match(r"^\s*", rows[0]).group(0)
    table = [cells(row) for row in rows]

    widths: list[int] = []
    for index, row in enumerate(table):
        if index == 1:
            continue
        for column, cell in enumerate(row):
            width = cell_width(cell)
            if column >= len(widths):
                widths.append(max(width, 3))
            elif width > widths[column]:
                widths[column] = width
    while len(widths) < len(separator):
        widths.append(3)

    rendered_rows: list[str] = []
    for index, row in enumerate(table):
        rendered: list[str] = []
        for column, cell in enumerate(row):
            if index == 1:
                left = ":" if cell.startswith(":") else ""
                right = ":" if cell.endswith(":") else ""
                rendered.append(left + "-" * (widths[column] - len(left) - len(right)) + right)
            else:
                rendered.append(cell + " " * (widths[column] - cell_width(cell)))
        rendered_rows.append(indent + "| " + " | ".join(rendered) + " |")
    return rendered_rows
