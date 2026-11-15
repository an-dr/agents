"""Locate the agents clone for an instruction change and report Git state."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path


BEGIN = "<!-- BEGIN agents-install -->"
END = "<!-- END agents-install -->"
POLICY = re.compile(r"[@`]([^\s`]+)/AGENTS\.md")


def same(left: Path, right: Path) -> bool:
    return os.path.normcase(str(left.resolve())) == os.path.normcase(str(right.resolve()))


def is_clone(path: Path) -> bool:
    return (path / "AGENTS.md").is_file() and (path / "skills/actions/an-dr-dev-follow-workflow/SKILL.md").is_file()


def git(root: Path, *arguments: str) -> str | None:
    result = subprocess.run(["git", "-C", str(root), *arguments], capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    return result.stdout.strip() if result.returncode == 0 else None


def repository_root(path: Path) -> Path | None:
    if not path.exists():
        return None
    current = path.resolve()
    if current.is_file():
        current = current.parent
    for directory in (current, *current.parents):
        if (directory / ".git").exists():
            return directory
    return None


def global_instructions() -> list[tuple[str, Path]]:
    home = Path.home()
    locations = (
        ("claude", home / ".claude/CLAUDE.md"),
        ("codex", home / ".codex/AGENTS.md"),
        ("copilot", home / ".copilot/copilot-instructions.md"),
        ("deepseek", home / ".dsh/AGENTS.md"),
        ("gemini", home / ".gemini/GEMINI.md"),
        ("opencode", home / ".config/opencode/AGENTS.md"),
    )
    found = []
    block = re.compile(re.escape(BEGIN) + r"(.*?)" + re.escape(END), re.DOTALL)
    for name, path in locations:
        if not path.is_file():
            continue
        match = block.search(path.read_text(encoding="utf-8-sig"))
        if match and (policy := POLICY.search(match.group(1))):
            found.append((f"global:{name}", Path(policy.group(1))))
    return found


def candidates(start: Path, explicit: Path | None) -> tuple[list[tuple[str, Path, bool]], Path | None]:
    found: list[tuple[str, Path, bool]] = []

    def add(source: str, path: Path | None) -> None:
        if path is None or not path.exists():
            return
        full = path.resolve()
        if any(name == source and same(known, full) for name, known, _ in found):
            return
        found.append((source, full, is_clone(full)))

    add("parameter", explicit)
    add("self", Path(__file__).resolve().parents[4])
    host = repository_root(start)
    if host:
        add("working-tree", host)
        add("submodule", host / "agents")
    for source, path in global_instructions():
        add(source, path)
    return found, host


def report(start: Path, explicit: Path | None) -> int:
    found, host = candidates(start, explicit)
    print("| Source | Path | Clone |\n| --- | --- | --- |")
    for source, path, clone in found:
        print(f"| {source} | `{path}` | {'yes' if clone else 'no'} |")
    if not found:
        print("| — | — | — |")
    print()
    if explicit and not is_clone(explicit):
        print(f"--agents-root '{explicit}' is not an agents clone; it needs AGENTS.md and skills/actions/an-dr-dev-follow-workflow/SKILL.md.")
        return 1
    clones = [(source, path) for source, path, clone in found if clone]
    if not clones:
        print("No agents clone found. Pass --agents-root with the path to one, or clone the repository first.")
        return 1
    explicit_clone = next((path for source, path in clones if source == "parameter"), None)
    distinct = {os.path.normcase(str(path)): path for _, path in clones}
    if explicit_clone:
        root = explicit_clone
    elif len(distinct) > 1:
        print(f"Found {len(distinct)} different agents clones. Ask the user which one to change, then re-run with --agents-root.")
        return 2
    else:
        root = next(iter(distinct.values()))
    print("| Fact | Value |\n| --- | --- |")
    print(f"| root | `{root}` |")
    notes = []
    if git(root, "rev-parse", "--git-dir") is None:
        print("| git | not a working tree |")
        notes.append("The clone is not a git working tree, so the change cannot be committed there.")
    else:
        branch = git(root, "branch", "--show-current") or ""
        print(f"| branch | {branch or 'detached HEAD'} |")
        if not branch:
            notes.append("HEAD is detached. Check out the default branch before committing, or the commit is unreachable.")
        status = (git(root, "status", "--porcelain") or "").splitlines()
        print(f"| working tree | {'clean' if not status else f'{len(status)} changed file(s)'} |")
        if status:
            notes.append("The clone already has uncommitted changes. Read them before staging, and never commit an unrelated one.")
        upstream = git(root, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}")
        if not upstream:
            print("| upstream | none |")
            notes.append("The branch has no upstream, so pushing needs an explicit remote and branch.")
        else:
            counts = (git(root, "rev-list", "--left-right", "--count", f"HEAD...{upstream}") or "?\t?").split()
            print(f"| upstream | {upstream} (ahead {counts[0]}, behind {counts[1]}) |")
    nested = bool(host and not same(host, root) and host in root.parents)
    print(f"| nested in | {'`' + str(host) + '`' if nested else '—'} |")
    if nested:
        notes.append(f"Committing here moves the gitlink in '{host}'. Follow the host's rule for submodule pointers; without one, leave the change uncommitted and tell the user.")
    print()
    for note in notes:
        print(f"- {note}")
    if notes:
        print()
    print(f"Resolved agents root: {root}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", "-Path", type=Path, default=Path.cwd())
    parser.add_argument("--agents-root", "-AgentsRoot", type=Path)
    args = parser.parse_args()
    try:
        return report(args.path, args.agents_root)
    except OSError as error:
        print(error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
