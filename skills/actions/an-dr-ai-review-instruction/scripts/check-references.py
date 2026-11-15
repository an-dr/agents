"""Check instruction links and skill names, then report context cost."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


LINK = re.compile(r"\]\(([^)]+)\)")
EXCLUDED = {".git", ".tmp-ai-gen", "node_modules"}


def visible(path: Path, root: Path) -> bool:
    return not any(part in EXCLUDED for part in path.relative_to(root).parts)


def frontmatter_name(path: Path) -> str:
    for line in path.read_text(encoding="utf-8-sig").splitlines()[:10]:
        match = re.fullmatch(r"name:\s*(\S+)\s*", line)
        if match:
            return match.group(1)
    return ""


def check(root: Path) -> tuple[list[tuple[str, int, str, str]], list[tuple[str, int]]]:
    findings: list[tuple[str, int, str, str]] = []
    manifests = [path for path in root.rglob("SKILL.md") if visible(path, root)]
    for manifest in manifests:
        name = frontmatter_name(manifest)
        if name != manifest.parent.name:
            findings.append((manifest.relative_to(root).as_posix(), 2, "skill.name", f"The frontmatter name '{name}' does not match directory '{manifest.parent.name}'."))
    for source in root.rglob("*.md"):
        if not visible(source, root):
            continue
        relative = source.relative_to(root).as_posix()
        for number, line in enumerate(source.read_text(encoding="utf-8-sig").splitlines(), 1):
            for match in LINK.finditer(line):
                target = match.group(1)
                if target.startswith(("http:", "https:", "mailto:", "#")):
                    continue
                cleaned = target.split("#", 1)[0]
                if cleaned and not (source.parent / cleaned).exists():
                    findings.append((relative, number, "reference.link", f"Link target '{cleaned}' does not resolve."))
    measured = []
    for path in (root / "AGENTS.md", root / "CLAUDE.md", *manifests):
        if path.is_file():
            measured.append((path.relative_to(root).as_posix(), round(path.stat().st_size / 4)))
    return sorted(findings), measured


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", "-Path", type=Path, default=Path.cwd())
    args = parser.parse_args()
    try:
        root = args.path.resolve(strict=True)
        findings, measured = check(root)
    except OSError as error:
        print(error, file=sys.stderr)
        return 1
    for file, line, rule, detail in findings:
        print(f"{file:<44} line {line:<4} {rule:<22} {detail}")
    print("\nContext cost (approximate tokens):")
    for file, tokens in sorted(measured, key=lambda item: item[1], reverse=True)[:10]:
        print(f"  {file:<46} {tokens:>7} tokens")
    print(f"  {'':46} {sum(tokens for _, tokens in measured):>7} tokens total across {len(measured)} file(s)")
    print(f"\n{len(findings)} broken reference(s).")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
