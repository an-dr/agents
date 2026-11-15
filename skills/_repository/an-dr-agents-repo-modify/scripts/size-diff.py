"""Report approximate token changes to instructions loaded by agents."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


LOADED = re.compile(r"^(?:AGENTS\.md|skills/[^/]+/[^/]+/(?:SKILL\.md|references/.+\.md))$")
SKILL = re.compile(r"^skills/[^/]+/[^/]+/SKILL\.md$")
DESCRIPTION = re.compile(r"^description:\s*(.*)$", re.MULTILINE)


def git(root: Path, *args: str, allow_missing: bool = False) -> str | None:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if result.returncode:
        if allow_missing:
            return None
        raise RuntimeError(result.stderr.strip() or f"git {' '.join(args)} failed")
    return result.stdout


def old_text(root: Path, base: str, path: str) -> str | None:
    result = git(root, "show", f"{base}:{path}", allow_missing=True)
    return result.rstrip("\n").replace("\r\n", "\n") if result is not None else None


def new_text(root: Path, path: str) -> str | None:
    file = root / path
    if not file.is_file():
        return None
    return "\n".join(file.read_text(encoding="utf-8-sig").splitlines())


def tokens(value: str | None) -> int:
    # PowerShell's Math.Round uses midpoint-to-even rounding.
    return round(len(value) / 4) if value is not None else 0


def description(value: str | None) -> str:
    match = DESCRIPTION.search(value or "")
    return match.group(1) if match else ""


def report(root: Path, base: str) -> str:
    if git(root, "rev-parse", "--verify", "--quiet", base, allow_missing=True) is None:
        raise RuntimeError(f"Unknown --base '{base}'.")
    changed = set((git(root, "diff", "--name-only", base) or "").splitlines())
    changed.update((git(root, "ls-files", "--others", "--exclude-standard") or "").splitlines())
    rows = []
    for path in sorted(path for path in changed if LOADED.fullmatch(path)):
        before = tokens(old_text(root, base, path))
        after = tokens(new_text(root, path))
        rows.append((path, before, after))

    old_skills = [path for path in (git(root, "ls-tree", "-r", "--name-only", base, "--", "skills") or "").splitlines() if SKILL.fullmatch(path)]
    new_skills = [path.relative_to(root).as_posix() for path in root.glob("skills/*/*/SKILL.md")]
    always_before = tokens(old_text(root, base, "AGENTS.md")) + sum(tokens(description(old_text(root, base, path))) for path in old_skills)
    always_after = tokens(new_text(root, "AGENTS.md")) + sum(tokens(description(new_text(root, path))) for path in new_skills)

    lines = ["| File | Before | After | Change |", "| --- | ---: | ---: | ---: |"]
    for path, before, after in rows:
        lines.append(f"| `{path}` | {before} | {after} | {after - before:+d} |".replace("| +0 |", "| 0 |"))
    before_sum = sum(before for _, before, _ in rows)
    after_sum = sum(after for _, _, after in rows)
    lines.append(f"| changed files | {before_sum} | {after_sum} | {after_sum - before_sum:+d} |".replace("| +0 |", "| 0 |"))
    lines.append(f"| always loaded | {always_before} | {always_after} | {always_after - always_before:+d} |".replace("| +0 |", "| 0 |"))
    lines.extend(["", "Approximate tokens (characters / 4). Always loaded: AGENTS.md and every skill description."])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", "-Root", type=Path, default=Path(__file__).resolve().parents[4])
    parser.add_argument("--base", "-Base", default="HEAD")
    args = parser.parse_args()
    try:
        print(report(args.root.resolve(), args.base))
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
