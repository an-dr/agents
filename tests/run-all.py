"""Discover and run skill test suites without executing fixture scripts."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SKILLS = ROOT / "skills"


@dataclass(frozen=True)
class Suite:
    skill: str
    folder: str
    runner: Path
    has_scripts: bool
    repository_check: bool
    dependencies: frozenset[str]


def git_output(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )


def changed_paths(base: str | None) -> set[str] | None:
    if git_output("rev-parse", "--is-inside-work-tree").returncode:
        return None
    status = git_output("status", "--porcelain=v1", "--untracked-files=all")
    if status.returncode:
        raise RuntimeError(status.stderr.strip() or "Could not inspect Git status.")
    paths = set()
    for line in status.stdout.splitlines():
        name = line[3:]
        if " -> " in name:
            name = name.rsplit(" -> ", 1)[1]
        paths.add(name.strip('"'))
    if base:
        diff = git_output("diff", "--name-only", f"{base}...HEAD")
        if diff.returncode:
            raise RuntimeError(f"Cannot compare with --base '{base}': {diff.stderr.strip()}")
        paths.update(diff.stdout.splitlines())
    return {path.replace("\\", "/") for path in paths}


def discover_suites() -> list[Suite]:
    suites = []
    for manifest in sorted(SKILLS.glob("*/*/SKILL.md")):
        skill_dir = manifest.parent
        tests_dir = skill_dir / "scripts" / "tests"
        runner = tests_dir / "run.py"
        frontmatter = manifest.read_text(encoding="utf-8-sig").splitlines()[:20]
        declared = next(
            (match.group(1) for line in frontmatter if (match := re.match(r"\s*an-dr\.dependencies:\s*(.*)$", line))),
            "",
        )
        suites.append(
            Suite(
                skill=skill_dir.name,
                folder=skill_dir.relative_to(ROOT).as_posix() + "/",
                runner=runner,
                has_scripts=(skill_dir / "scripts").is_dir(),
                repository_check=bool(list(tests_dir.glob("test-repository*.py"))),
                dependencies=frozenset(declared.split()),
            )
        )
    return suites


def run_suite(suite: Suite) -> tuple[int, str]:
    if not suite.runner.is_file():
        return 1, f"Missing conventional runner: {suite.runner}"
    command = [sys.executable, str(suite.runner)]
    try:
        result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    except OSError as error:
        return 1, str(error)
    return result.returncode, result.stdout + result.stderr


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", "-All", action="store_true", help="Run every skill suite.")
    parser.add_argument("--base", "-Base", help="Include changes since this Git ref.")
    args = parser.parse_args()

    suites = discover_suites()
    steps = [suite for suite in suites if suite.has_scripts]
    if not steps:
        raise RuntimeError(f"No conventional skill test runners found under '{SKILLS}'.")
    if not args.all:
        changed = changed_paths(args.base)
        if changed is None:
            print("Not a Git working tree, so changes are unknown: running every suite.")
        elif not changed:
            print("Nothing changed, so no suite is affected. Run with --all for every suite.")
            return 0
        else:
            changed_skills = {suite.skill for suite in suites if any(path.startswith(suite.folder) for path in changed)}
            steps = [suite for suite in steps if suite.repository_check or suite.skill in changed_skills or bool(suite.dependencies & changed_skills)]
            print(f"Affected suites: {len(steps)} of {len([suite for suite in suites if suite.has_scripts])} ({len(changed)} changed file(s)). Run with --all for every suite.\n")

    results = [(suite, *run_suite(suite)) for suite in steps]
    for suite, code, output in results:
        if code:
            print(f"### {suite.runner.relative_to(ROOT).as_posix()} failed (exit {code})\n")
            print(f"```text\n{output.rstrip()}\n```\n")
    print("| Step | Result |\n| --- | --- |")
    for suite, code, _ in results:
        status = "pass" if code == 0 else f"FAIL (exit {code})"
        print(f"| `{suite.runner.relative_to(ROOT).as_posix()}` | {status} |")
    passed = sum(code == 0 for _, code, _ in results)
    print(f"\n{passed} of {len(results)} step(s) passed.")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as error:
        print(error, file=sys.stderr)
        sys.exit(1)
