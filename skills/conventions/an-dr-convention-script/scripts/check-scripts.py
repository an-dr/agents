"""Check skill scripts for test runners, syntax, and portable paths."""

from __future__ import annotations

import argparse
import ast
import re
import sys
from pathlib import Path


SIBLING = re.compile(r"\.\./\.\./(?:\.\./)?(?:[a-z_-]+/)?(?P<skill>[a-z0-9-]+)")


def check(root: Path) -> tuple[int, list[tuple[str, str]]]:
    skills = root / "skills"
    folders = {path.name for path in skills.glob("*/*") if path.is_dir()}
    problems: list[tuple[str, str]] = []
    scripts = [path for path in skills.rglob("*.py") if "__pycache__" not in path.parts]
    for folder in skills.glob("*/*/scripts"):
        if not folder.is_dir():
            continue
        relative = folder.relative_to(root).as_posix()
        if not (folder / "tests" / "run.py").is_file():
            problems.append((relative, "missing tests/run.py"))
        for test in folder.glob("test-*.py"):
            problems.append((relative, f"{test.name} belongs in scripts/tests/, not scripts/"))
    for file in (*skills.rglob("*.ps1"), *skills.rglob("*.psm1")):
        if "fixtures" in file.parts:
            continue
        problems.append((file.relative_to(root).as_posix(), "PowerShell script remains; port it to Python"))
    for file in scripts:
        relative = file.relative_to(root).as_posix()
        text = file.read_text(encoding="utf-8-sig")
        try:
            ast.parse(text, filename=relative)
        except SyntaxError as error:
            problems.append((relative, f"Python syntax error at line {error.lineno}: {error.msg}"))
        for match in SIBLING.finditer(text):
            target = match.group("skill")
            if target in folders:
                problems.append((relative, f"guesses where {target} is installed; take its folder as a named skill parameter"))
    return len(scripts), problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", "-Root", type=Path, default=Path(__file__).resolve().parents[4])
    args = parser.parse_args()
    root = args.root.resolve()
    count, problems = check(root)
    if not problems:
        print(f"Script check passed: {count} scripts follow script.")
        return 0
    print(f"Script check: {len(problems)} problem(s).\n")
    print("| Where | Problem |\n| --- | --- |")
    for location, problem in problems:
        safe_problem = problem.replace("|", "\\|")
        print(f"| `{location}` | {safe_problem} |")
    return 1


if __name__ == "__main__":
    sys.exit(main())
