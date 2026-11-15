"""Check this repository's skill names against their declared types."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


NAMESPACE = "an-dr-"
GROUPS = ("ai-skill", "ai", "dev", "architecture", "project", "text", "git", "files", "env")


def allowed_verbs() -> set[str]:
    skill = Path(__file__).resolve().parent.parent / "SKILL.md"
    verbs: set[str] = set()
    in_table = False
    for line in skill.read_text(encoding="utf-8-sig").splitlines():
        if line.startswith("## "):
            in_table = line == "## Verbs"
            continue
        if in_table and (match := re.match(r"^\|\s*`([a-z]+)`\s*\|", line)):
            verbs.add(match.group(1))
    if not verbs:
        raise ValueError(f"No verbs found in the Verbs table of {skill}.")
    return verbs


def skill_type(path: Path) -> str:
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if match := re.fullmatch(r"\s+an-dr\.type:\s*(\S+)\s*", line):
            return match.group(1)
    return ""


def check(root: Path) -> tuple[int, list[tuple[str, str]]]:
    verbs = allowed_verbs()
    files = sorted(root.glob("skills/*/*/SKILL.md"))
    problems: list[tuple[str, str]] = []
    for file in files:
        name = file.parent.name
        category = file.parent.parent.name
        where = f"skills/{category}/{name}"
        kind = skill_type(file)

        def problem(message: str) -> None:
            problems.append((where, message))

        if not name.startswith(NAMESPACE):
            problem(f"name must start with '{NAMESPACE}'")
            continue
        rest = name[len(NAMESPACE) :]
        parts = rest.split("-")
        if category.startswith("_"):
            if not rest.startswith("agents-"):
                problem(f"a skill of the repository itself must be named {NAMESPACE}agents-<name>")
                continue
            if kind == "concept" and not re.fullmatch(r"agents-repo-concept-.+", rest):
                problem(f"a concept of the repository itself must be named {NAMESPACE}agents-repo-concept-<name>")
            elif kind == "convention" and not re.fullmatch(r"agents-repo-convention-.+", rest):
                problem(f"a convention of the repository itself must be named {NAMESPACE}agents-repo-convention-<name>")
            elif kind == "action":
                tail = re.sub(r"^agents-(?:repo-)?", "", rest).split("-")
                if tail[0] not in verbs:
                    problem(f"verb '{tail[0]}' is not in the Verbs table")
            continue
        if kind == "concept":
            if not re.fullmatch(r"concept-.+", rest):
                problem(f"a concept must be named {NAMESPACE}concept-<name>")
        elif kind == "convention":
            if not re.fullmatch(r"convention-.+", rest):
                problem(f"a convention must be named {NAMESPACE}convention-<name>")
        elif kind == "action":
            if len(parts) < 2:
                problem("an action needs a group and a verb: <group>-<verb>[-<noun>]")
                continue
            group = next((item for item in sorted(GROUPS, key=len, reverse=True) if rest == item or rest.startswith(item + "-")), None)
            if not group:
                problem(f"group '{parts[0]}' is not one of {', '.join(GROUPS)}")
                continue
            tail = rest[len(group) :].lstrip("-")
            if not tail:
                problem("an action needs a group and a verb: <group>-<verb>[-<noun>]")
            elif (verb := tail.split("-")[0]) not in verbs:
                problem(f"verb '{verb}' is not in the Verbs table")
    return len(files), problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", "-Root", type=Path, default=Path(__file__).resolve().parents[4])
    args = parser.parse_args()
    try:
        count, problems = check(args.root.resolve())
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    if not problems:
        print(f"Name check passed: {count} skills follow the naming rule.")
        return 0
    print(f"Name check: {len(problems)} problem(s).\n")
    print("| Where | Problem |\n| --- | --- |")
    for where, what in problems:
        safe_what = what.replace("|", "\\|")
        print(f"| `{where}` | {safe_what} |")
    return 1


if __name__ == "__main__":
    sys.exit(main())
