"""Join hard-wrapped paragraphs and list items back onto single lines.

A file whose words would change is refused, so content cannot be lost.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path


EXCLUDED = re.compile(r"\\(?:\.git|node_modules)\\", re.IGNORECASE)
FENCE = re.compile(r"^\s*```")
HEADING = re.compile(r"^#{1,6}\s")
TABLE_ROW = re.compile(r"^\s*\|")
RULE = re.compile(r"^\s*(?:-{3,}|\*{3,}|_{3,})\s*$")
QUOTE = re.compile(r"^\s*>")
LIST_ITEM = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s")


def read_file(path: Path) -> str:
    """Read a file as the original did: UTF-8, BOM stripped, undecodable bytes replaced."""
    return path.read_bytes().decode("utf-8-sig", errors="replace")


def reflowed_text(lines: list[str]) -> str:
    """Return the file's content with wrapped paragraphs and list items joined."""
    output: list[str] = []
    buffer: list[str] = []
    in_fence = False
    index = 0

    def complete() -> None:
        if buffer:
            output.append(" ".join(buffer))
            buffer.clear()

    # Frontmatter is copied through untouched.
    if lines and lines[0] == "---":
        output.append(lines[0])
        index = 1
        while index < len(lines):
            output.append(lines[index])
            closed = lines[index] == "---"
            index += 1
            if closed:
                break

    while index < len(lines):
        line = lines[index]
        index += 1

        if FENCE.match(line):
            complete()
            output.append(line)
            in_fence = not in_fence
            continue
        if in_fence:
            output.append(line)
            continue

        # Structural lines stand alone and end whatever was being collected.
        if not line or HEADING.match(line) or TABLE_ROW.match(line) or RULE.match(line) or QUOTE.match(line):
            complete()
            output.append(line)
            continue

        # A new list item starts its own buffer; its continuation lines join it.
        if LIST_ITEM.match(line):
            complete()
            buffer.append(line.rstrip())
            continue

        buffer.append(line.strip())
    complete()

    return "\n".join(output)


def word_signature(text: str) -> str:
    """Collapse text to its words, so only wrapping may differ."""
    return re.sub(r"\s+", " ", text).strip()


def collect(target: Path) -> list[Path]:
    """List the Markdown files the given file or directory holds, in directory order."""
    if not target.is_dir():
        if not target.exists():
            raise FileNotFoundError(f"Cannot find path '{target}' because it does not exist.")
        return [target]
    files: list[Path] = []

    def walk(directory: Path) -> None:
        # Files of one directory come before its subdirectories, as directory listings do.
        names = sorted(entry.name for entry in directory.iterdir())
        for name in names:
            path = directory / name
            if path.is_file() and path.suffix.lower() == ".md" and not EXCLUDED.search(str(path)):
                files.append(path)
        for name in names:
            path = directory / name
            if path.is_dir() and name.lower() not in (".git", "node_modules"):
                walk(path)

    walk(target)
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", "-Path", dest="target", type=Path, metavar="Path")
    parser.add_argument("paths", nargs="*", type=Path, metavar="Path")
    parser.add_argument("--what-if-only", "-WhatIfOnly", action="store_true")
    args = parser.parse_args()
    targets = ([args.target] if args.target else []) + args.paths
    if len(targets) != 1:
        parser.error("exactly one path is required, as --path or as the first argument")
    try:
        files = [Path(os.path.abspath(path)) for path in collect(targets[0])]
    except OSError as error:
        print(error, file=sys.stderr)
        return 1
    if not files:
        print(f"No Markdown files found at '{targets[0]}'.", file=sys.stderr)
        return 1

    changed = 0
    for path in files:
        original = read_file(path)
        lines = original.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        reflowed = reflowed_text(lines).rstrip() + "\n"

        # Keep the file's own line endings, so a no-op run rewrites nothing.
        if "\r\n" in original:
            reflowed = reflowed.replace("\n", "\r\n")

        if word_signature(original) != word_signature(reflowed):
            print(f"Reflowing '{path}' would change its words; nothing was written.", file=sys.stderr)
            return 1
        if reflowed == original:
            continue

        changed += 1
        print(path)
        if not args.what_if_only:
            path.write_bytes(reflowed.encode("utf-8"))

    print()
    verb = "would change" if args.what_if_only else "changed"
    print(f"{len(files)} file(s) checked, {changed} {verb}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
