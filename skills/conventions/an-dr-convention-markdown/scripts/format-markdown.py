"""Format Markdown files.

Aligns tables, removes trailing whitespace, and ends each file with one newline.
Frontmatter, code fences, and HTML comments stay untouched. A file whose text
would change is refused, so content cannot be lost.
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

EXCLUDED = re.compile(r"[\\/](?:\.git|node_modules)[\\/]", re.IGNORECASE)
FENCE = re.compile(r"^\s*```")
COMMENT_START = re.compile(r"^\s*<!--")
TABLE_ROW = re.compile(r"^\s*\|.*\|\s*$")


def read_file(path: Path) -> str:
    """Read a file as the original did: UTF-8, BOM stripped, undecodable bytes replaced."""
    return path.read_bytes().decode("utf-8-sig", errors="replace")


def formatted_lines(lines: list[str]) -> list[str]:
    """Return the file's lines in their formatted form."""
    output: list[str] = []
    index = 0

    if lines and lines[0] == "---":
        output.append(lines[0])
        index = 1
        while index < len(lines):
            output.append(lines[index])
            closed = lines[index] == "---"
            index += 1
            if closed:
                break

    in_fence = False
    in_comment = False
    while index < len(lines):
        line = lines[index]

        if in_fence or FENCE.match(line):
            if FENCE.match(line):
                in_fence = not in_fence
            output.append(line)
            index += 1
            continue
        if in_comment or COMMENT_START.match(line):
            in_comment = not re.search(r"-->", line)
            output.append(line)
            index += 1
            continue
        if TABLE_ROW.match(line):
            rows: list[str] = []
            while index < len(lines) and TABLE_ROW.match(lines[index]):
                rows.append(lines[index])
                index += 1
            output.extend(row.rstrip() for row in format_markdown_table(rows))
            continue

        output.append(line.rstrip())
        index += 1
    return output


def text_signature(text: str) -> str:
    """Remove everything the formatter may change: whitespace and separator dashes."""
    return re.sub(r"-+", "-", re.sub(r"\s+", "", text))


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
    parser.add_argument("--what-if-only", "-WhatIfOnly", action="store_true")
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

    changed = 0
    for path in files:
        original = read_file(path)
        lines = original.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        formatted = "\n".join(formatted_lines(lines)).rstrip() + "\n"

        # Keep the file's own line endings, so a no-op run rewrites nothing.
        if "\r\n" in original:
            formatted = formatted.replace("\n", "\r\n")

        if text_signature(original) != text_signature(formatted):
            print(f"Formatting '{path}' would change its text; nothing was written.", file=sys.stderr)
            return 1
        if formatted == original:
            continue

        changed += 1
        print(path)
        if not args.what_if_only:
            path.write_bytes(formatted.encode("utf-8"))

    print()
    verb = "would change" if args.what_if_only else "changed"
    print(f"{len(files)} file(s) checked, {changed} {verb}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
