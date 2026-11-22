"""Flag lines in a git diff that weaken checks: suppressions, skipped tests, removed assertions, stubs, deleted tests."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


# Each pattern matches an added line; the label names what it weakens.
ADDED = [
    ("suppression", re.compile(r"eslint-disable|@ts-ignore|@ts-nocheck|@ts-expect-error|#\s*noqa|#\s*type:\s*ignore|pylint:\s*disable|NOLINT|#\[allow\(|@SuppressWarnings|#pragma warning disable|istanbul ignore|c8 ignore|nolint|rubocop:disable")),
    ("skipped test", re.compile(r"\b(?:it|describe|test)\.(?:skip|todo)\(|\bx(?:it|describe|test)\(|@pytest\.mark\.(?:skip|xfail)|@unittest\.skip|\bpytest\.skip\(|#\[ignore\]|\bt\.Skip(?:Now)?\(|\[Ignore\]|@Disabled\b|\bself\.skipTest\(")),
    ("stub", re.compile(r"raise NotImplementedError|\btodo!\(|\bunimplemented!\(|not implemented['\"]|throw new NotImplementedException")),
]
ASSERTION = re.compile(r"\bassert\w*\b|\bexpect\(|\bassert_eq!|\bassert!|\bshould\.|\bEXPECT_|\bASSERT_|\brequire\.\w+\(")
TEST_FILE = re.compile(r"(?:^|/)(?:tests?|__tests__|spec)/|(?:^|/)test[-_][^/]*$|[-_.](?:test|spec)\.[^/]+$|_test\.go$")


@dataclass
class Hit:
    kind: str
    file: str
    line: int | None
    text: str


def diff_text(reference: str | None, staged: bool) -> str:
    command = ["git", "diff", "--unified=0", "--no-color", "-M"]
    if staged:
        command.append("--cached")
    if reference:
        command.append(reference)
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    if result.returncode:
        raise ValueError(result.stderr.strip() or "git diff failed; run inside the reviewed repository.")
    return result.stdout


def scan(diff: str) -> list[Hit]:
    hits: list[Hit] = []
    file = ""
    line = 0
    removed_asserts: dict[str, int] = {}
    added_asserts: dict[str, int] = {}
    deleted = False
    for raw in diff.splitlines():
        if raw.startswith("diff --git "):
            deleted = False
            file = raw.split(" b/", 1)[-1]
        elif raw.startswith("deleted file mode"):
            deleted = True
            if TEST_FILE.search(file):
                hits.append(Hit("deleted test file", file, None, ""))
        elif raw.startswith("@@"):
            match = re.search(r"\+(\d+)", raw)
            line = int(match.group(1)) if match else 0
        elif raw.startswith("+") and not raw.startswith("+++"):
            text = raw[1:]
            for kind, pattern in ADDED:
                if pattern.search(text):
                    hits.append(Hit(kind, file, line, text.strip()))
            if ASSERTION.search(text):
                added_asserts[file] = added_asserts.get(file, 0) + 1
            line += 1
        elif raw.startswith("-") and not raw.startswith("---") and not deleted:
            if ASSERTION.search(raw[1:]):
                removed_asserts[file] = removed_asserts.get(file, 0) + 1
    for name, count in removed_asserts.items():
        net = count - added_asserts.get(name, 0)
        if net > 0:
            hits.append(Hit("removed assertions", name, None, f"{net} more assertion line(s) removed than added"))
    return hits


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", "-Reference", help="Compare against this ref; default is uncommitted changes.")
    parser.add_argument("--staged", "-Staged", action="store_true", help="Check the staged changes.")
    parser.add_argument("--diff-path", "-DiffPath", type=Path, help="Read a saved unified diff instead of running git.")
    args = parser.parse_args()
    try:
        diff = args.diff_path.read_text(encoding="utf-8") if args.diff_path else diff_text(args.reference, args.staged)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    hits = scan(diff)
    if not hits:
        print("No weakening found in the diff.")
        return 0
    print("| Kind | File | Line | Text |\n| --- | --- | --- | --- |")
    for hit in hits:
        text = hit.text.replace("|", "\\|")[:120]
        print(f"| {hit.kind} | `{hit.file}` | {hit.line or ''} | {text} |")
    print(f"{len(hits)} possible weakening(s); judge each against the diff's stated reason.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
