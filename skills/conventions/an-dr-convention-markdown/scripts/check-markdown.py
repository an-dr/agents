"""Check Markdown files against the markdown format rules.

Exits non-zero on any error, including hard-wrapped paragraphs.
"""

from __future__ import annotations

import argparse
import os
import re
import runpy
import sys
from pathlib import Path


TABLE = runpy.run_path(str(Path(__file__).resolve().parent / "markdown-table.py"))
format_markdown_table = TABLE["format_markdown_table"]

EXCLUDED = re.compile(r"\\(?:\.git|node_modules)\\", re.IGNORECASE)
FENCE = re.compile(r"^\s*```")
FENCE_LANGUAGE = re.compile(r"^\s*```[A-Za-z0-9]")
COMMENT = re.compile(r"(?P<ticks>`+)(?!`).*?(?<!`)(?P=ticks)(?!`)|(?<!\\)<!--")
TRAILING = re.compile(r"\s+$")
UNDERSCORE_EMPHASIS = re.compile(r"^__[^_]+__|(?<![A-Za-z0-9_])_[^_\s][^_]*_(?![A-Za-z0-9_])", re.IGNORECASE)
WEAK_LINK_TEXT = re.compile(r"\[(here|this|link)\]\(", re.IGNORECASE)
HEADING = re.compile(r"^(#{1,6})\s")
HEADING_PUNCTUATION = re.compile(r"[.,;:!]\s*$")
TABLE_ROW = re.compile(r"^\s*\|.*\|\s*$")
LIST_ITEM = re.compile(r"^\s*(?:[-*+]|\d+\.)\s")
FOREIGN_BULLET = re.compile(r"^\s*[*+]\s")


def read_file(path: Path) -> str:
    """Read a file as the original did: UTF-8, BOM stripped, undecodable bytes replaced."""
    return path.read_bytes().decode("utf-8-sig", errors="replace")


def split_visible(line: str, in_comment: bool) -> tuple[str, bool, bool]:
    """Split one line into the text a reader sees, the comment state, and whether a comment ran."""
    remaining = line
    visible = ""
    has_comment = in_comment
    while remaining:
        if in_comment:
            end = remaining.find("-->")
            if end < 0:
                break
            remaining = remaining[end + 3 :]
            in_comment = False
            continue
        marker = COMMENT.search(remaining)
        if marker is None:
            visible += remaining
            break
        if marker.group(0) != "<!--":
            visible += remaining[: marker.end()]
            remaining = remaining[marker.end() :]
            continue
        visible += remaining[: marker.start()]
        remaining = remaining[marker.start() + 4 :]
        in_comment = True
        has_comment = True
    return visible, in_comment, has_comment


def violations(path: Path) -> list[tuple[str, str, int, str]]:
    """Return the rule violations found in one Markdown file."""
    found: list[tuple[str, str, int, str]] = []

    def add(rule: str, line: int, detail: str) -> None:
        found.append(("error", rule, line, detail))

    raw = read_file(path)
    lines = raw.replace("\r\n", "\n").replace("\r", "\n").split("\n")

    if not raw.endswith("\n"):
        add("file.newline", len(lines), "The file does not end with a newline.")
    elif raw.endswith("\n\n"):
        add("file.newline", len(lines), "The file ends with more than one newline.")

    in_fence = False
    in_comment = False
    heading_count = 0
    previous_level = 0
    paragraph_start = -1
    paragraph_lines = 0
    table_end = 0

    # YAML frontmatter is not Markdown; skip past its closing fence.
    start = 0
    if lines[0] == "---":
        for index in range(1, len(lines)):
            if lines[index] == "---":
                start = index + 1
                break
        if start == 0:
            add("frontmatter.unclosed", 1, "The frontmatter block is never closed.")

    for index in range(start, len(lines)):
        source_line = lines[index]
        line = source_line
        number = index + 1
        previous = lines[index - 1] if index > 0 else ""

        # Comments may contain Markdown syntax, but it is not rendered prose.
        if not in_fence:
            line, in_comment, has_comment = split_visible(line, in_comment)
            if has_comment and not line.strip():
                if paragraph_lines > 1:
                    add("line.wrap", paragraph_start, f"The paragraph is hard-wrapped across {paragraph_lines} lines.")
                paragraph_start = -1
                paragraph_lines = 0
                continue

        if FENCE.match(line):
            if not in_fence:
                if not FENCE_LANGUAGE.match(line):
                    add("fence.language", number, "The code fence names no language.")
                if index > 0 and previous != "":
                    add("fence.blank", number, "A blank line precedes a code fence.")
            in_fence = not in_fence
            paragraph_start = -1
            paragraph_lines = 0
            continue
        if in_fence:
            continue

        if TRAILING.search(source_line):
            add("line.trailing", number, "The line carries trailing whitespace.")
        if UNDERSCORE_EMPHASIS.search(line):
            add("emphasis.marker", number, "Emphasis uses ** and *, never underscores.")
        if WEAK_LINK_TEXT.search(line):
            add("link.text", number, "Link text describes its target.")

        heading = HEADING.match(line)
        if heading:
            level = len(heading.group(1))
            if level == 1:
                heading_count += 1
            if previous_level > 0 and level > previous_level + 1:
                add("heading.level", number, f"The heading jumps from level {previous_level} to {level}.")
            if HEADING_PUNCTUATION.search(line):
                add("heading.punctuation", number, "The heading ends with punctuation.")
            if index > 0 and previous != "":
                add("heading.blank", number, "A blank line precedes a heading.")
            previous_level = level
            paragraph_start = -1
            paragraph_lines = 0
            continue

        if TABLE_ROW.match(line):
            if index >= table_end:
                table_end = index
                while table_end < len(lines) and TABLE_ROW.match(lines[table_end]):
                    table_end += 1
                rows = lines[index:table_end]
                if "\n".join(format_markdown_table(rows)) != "\n".join(rows):
                    add("table.align", number, "The table columns are not aligned; run format-markdown.py.")
            paragraph_start = -1
            paragraph_lines = 0
            continue

        if LIST_ITEM.match(line):
            if FOREIGN_BULLET.match(line):
                add("list.marker", number, 'Bullets use "-".')
            paragraph_start = -1
            paragraph_lines = 0
            continue

        # Prose spanning several lines is a hard wrap: one paragraph is one line.
        if line == "":
            if paragraph_lines > 1:
                add("line.wrap", paragraph_start, f"The paragraph is hard-wrapped across {paragraph_lines} lines.")
            paragraph_start = -1
            paragraph_lines = 0
        else:
            if paragraph_start < 0:
                paragraph_start = number
            paragraph_lines += 1

    if paragraph_lines > 1:
        add("line.wrap", paragraph_start, f"The paragraph is hard-wrapped across {paragraph_lines} lines.")
    if in_fence:
        add("fence.unclosed", len(lines), "A code fence is never closed.")
    if heading_count > 1:
        add("heading.single", 1, f"The file holds {heading_count} level-one headings; it takes one.")
    return found


def collect(targets: list[Path]) -> list[Path]:
    """List the Markdown files the given files and directories hold."""
    files: list[Path] = []
    for target in targets:
        if target.is_dir():
            for root, directories, names in os.walk(target, onerror=None):
                directories[:] = [name for name in directories if name.lower() not in (".git", "node_modules")]
                for name in names:
                    path = Path(root) / name
                    if path.suffix.lower() == ".md" and not EXCLUDED.search(str(path)):
                        files.append(path)
        elif target.exists():
            files.append(target)
        else:
            raise FileNotFoundError(f"Cannot find path '{target}' because it does not exist.")
    # One entry per path, in a case-insensitive name order, as the original's sorted full names were.
    unique: dict[str, Path] = {}
    for path in files:
        unique.setdefault(os.path.normcase(str(path)), path)
    return [unique[key] for key in sorted(unique)]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", "-Path", dest="targets", nargs="+", type=Path, metavar="Path")
    parser.add_argument("paths", nargs="*", type=Path, metavar="Path")
    args = parser.parse_args()
    targets = (args.targets or []) + args.paths
    if not targets:
        parser.error("a path is required, as --path or as the first argument")
    try:
        files = [Path(os.path.abspath(path)) for path in collect(targets)]
    except OSError as error:
        print(error, file=sys.stderr)
        return 1
    if not files:
        names = " ".join(str(path) for path in targets)
        print(f"No Markdown files found at '{names}'.", file=sys.stderr)
        return 1

    errors = 0
    warnings = 0
    for path in files:
        items = violations(path)
        file_errors = sum(1 for item in items if item[0] == "error")
        errors += file_errors
        warnings += len(items) - file_errors
        if not items:
            continue
        print(path)
        for severity, rule, line, detail in sorted(items, key=lambda item: item[2]):
            print(f"  {severity:<7} line {line:<4} {rule:<20} {detail}")

    print()
    print(f"{len(files)} file(s) checked, {errors} error(s), {warnings} warning(s).")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
