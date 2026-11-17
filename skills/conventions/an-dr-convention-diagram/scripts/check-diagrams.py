"""Measure Mermaid diagrams against the one-level reading budget."""

from __future__ import annotations

import argparse
import html
import re
import sys
from dataclasses import dataclass
from pathlib import Path


EDGE = re.compile(r"^(?P<source>\[\*\]|[\w.-]+)(?:\s*(?P<source_shape>[\[({>])[^\n]*?[\])}]+)?\s*(?P<arrow>--?>|==+>|-\.->|---|--\s[^-]+-->|-->)\s*(?:\|(?P<pipe>[^|]*)\|)?\s*(?P<target>\[\*\]|[\w.-]+)(?:\s*(?P<target_shape>[\[({>])[^\n]*?[\])}]+)?\s*(?::\s*(?P<colon>.+))?$")


@dataclass
class Measure:
    nodes: int
    labelled: int
    levels: int
    loops: int
    direction: str
    long_labels: list[str]

    @property
    def items(self) -> int:
        return self.nodes + self.labelled


def files(paths: list[Path]) -> list[Path]:
    found = []
    for path in paths:
        if not path.exists():
            raise ValueError(f"Path not found: {path}")
        if path.is_dir():
            found.extend(file for file in path.rglob("*") if file.is_file() and file.suffix.lower() in (".md", ".html") and not any(part in (".git", "node_modules") for part in file.parts))
        else:
            found.append(path)
    return found


def blocks(text: str, extension: str) -> list[tuple[int, str]]:
    if extension == ".html":
        return [(text.count("\n", 0, match.start()) + 1, html.unescape(match.group(1))) for match in re.finditer(r'<pre class="mermaid"[^>]*>(.*?)</pre>', text, re.DOTALL)]
    lines = text.splitlines()
    result = []
    start = None
    for index, line in enumerate(lines):
        if start is None and re.fullmatch(r"\s*(?:```|~~~)\s*mermaid\s*", line):
            start = index
        elif start is not None and re.fullmatch(r"\s*(?:```|~~~)\s*", line):
            result.append((start + 1, "\n".join(lines[start + 1 : index])))
            start = None
    return result


def measure(source: str, max_label_words: int) -> Measure | str | None:
    all_lines = [line.strip() for line in source.splitlines() if line.strip()]
    exempt = any(re.match(r"^%%\s*diagram-budget:\s*exempt(?:\s|$)", line) for line in all_lines)
    # Boundaries that are the point of the diagram -- layers, phases -- frame
    # leaf nodes only, so they may draw one level of groups and no deeper.
    boundaries = any(re.match(r"^%%\s*diagram-budget:\s*boundaries(?:\s|$)", line) for line in all_lines)
    lines = [line for line in all_lines if not line.startswith("%%")]
    if not lines:
        return None
    if exempt:
        return "exempt"
    header = lines[0]
    state = header.startswith("stateDiagram")
    if not state and not re.match(r"^(?:flowchart|graph)\b", header):
        return None
    direction = "LR" if re.search(r"\b(?:LR|RL)\b", header) else "TB"
    order: list[str] = []
    edges: list[tuple[str, str, str | None]] = []
    decisions: set[str] = set()
    depth = 0
    max_depth = 0
    long_labels = []

    def add_node(identifier: str) -> None:
        if identifier and identifier != "[*]" and identifier not in order:
            order.append(identifier)

    for line in lines[1:]:
        if match := re.match(r"^direction\s+(LR|RL|TB|TD|BT)", line):
            if depth == 0:
                direction = "LR" if match.group(1) in ("LR", "RL") else "TB"
            continue
        if re.match(r"^(?:classDef|class|style|linkStyle|click|note)\b", line):
            continue
        if line.startswith("subgraph ") or (state and re.match(r"^state\s+.*\{\s*$", line)):
            depth += 1
            max_depth = max(max_depth, depth)
            continue
        if line in ("end", "}"):
            depth = max(0, depth - 1)
            continue
        if match := EDGE.match(line):
            label = match.group("pipe") or match.group("colon")
            if not label and (arrow_label := re.match(r"^--\s(.+)-->$", match.group("arrow"))):
                label = arrow_label.group(1)
            label = label.replace('"', "").strip() if label else None
            source_id, target_id = match.group("source"), match.group("target")
            add_node(source_id)
            add_node(target_id)
            if match.group("source_shape") == "{":
                decisions.add(source_id)
            if match.group("target_shape") == "{":
                decisions.add(target_id)
            edges.append((source_id, target_id, label))
            if label and len(label.split()) > max_label_words:
                long_labels.append(label)
            continue
        if match := re.match(r"^([\w.-]+)\s*([\[({>])", line):
            add_node(match.group(1))
            if match.group(2) == "{":
                decisions.add(match.group(1))
            continue
        if state and (match := re.match(r'^state\s+"[^"]*"\s+as\s+([\w.-]+)', line)):
            add_node(match.group(1))
            continue
        if state and (match := re.match(r"^([\w.-]+)\s*:", line)):
            add_node(match.group(1))
    loops = sum(source_id != "[*]" and target_id != "[*]" and order.index(target_id) <= order.index(source_id) for source_id, target_id, _ in edges)
    labelled = sum(bool(label) and source_id != "[*]" and target_id != "[*]" and not (source_id in decisions and len(label.split()) == 1) for source_id, target_id, label in edges)
    levels = 1 + max(0, max_depth - 1) if boundaries else 1 + max_depth
    return Measure(len(order), labelled, levels, loops, direction, long_labels)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", "-Path", nargs="+", type=Path, required=True)
    parser.add_argument("--max-items", "-MaxItems", type=int, default=7)
    parser.add_argument("--max-loops", "-MaxLoops", type=int, default=1)
    parser.add_argument("--max-label-words", "-MaxLabelWords", type=int, default=2)
    parser.add_argument("--max-row-nodes", "-MaxRowNodes", type=int, default=4)
    args = parser.parse_args()
    over = measured = unmeasured = exempted = 0
    try:
        for file in files(args.path):
            text = file.read_text(encoding="utf-8-sig")
            for line, source in blocks(text, file.suffix.lower()):
                result = measure(source, args.max_label_words)
                if result is None:
                    unmeasured += 1
                    continue
                if result == "exempt":
                    exempted += 1
                    continue
                measured += 1
                problems = []
                if result.items > args.max_items:
                    problems.append(f"items {result.items} > {args.max_items} ({result.nodes} nodes, {result.labelled} labelled edges)")
                if result.levels > 1:
                    problems.append(f"levels {result.levels} > 1 (a group has its own inside; make it a black box)")
                if result.loops > args.max_loops:
                    problems.append(f"loops {result.loops} > {args.max_loops}")
                if result.direction == "LR" and result.nodes > args.max_row_nodes:
                    problems.append(f"left-to-right with {result.nodes} nodes > {args.max_row_nodes}")
                problems.extend(f"label '{label}' is over {args.max_label_words} words" for label in result.long_labels)
                if problems:
                    over += 1
                    print(f"{file.resolve()}:{line}")
                    for problem in problems:
                        print(f"  over    {problem}")
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    print(f"\n{measured} diagram(s) measured, {over} over budget, {exempted} exempt, {unmeasured} of other types not measured.")
    return 1 if over else 0


if __name__ == "__main__":
    sys.exit(main())
