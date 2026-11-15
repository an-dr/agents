"""Check that a repository describes its skills consistently.

Every skill sits one level below a category folder (actions, concepts,
conventions, or a folder whose name starts with an underscore for skills of the
repository itself), is registered in skills/README.md, has a name matching its
folder and, for a concept or convention, containing its type, declares its
an-dr.type and an-dr.dependencies, agrees with its folder on its type, names
only the skills it declares (PROHIBITED forbids any, none allows none today),
and never depends on a skill of the repository's own folder unless it lives
there. Dependency cycles are listed with their path, and concept skills hold
SKILL.md and evals only, without production scripts.
Prints a Markdown table of problems and exits 1 when there are any, or on a
cycle when --fail-on-cycle is given.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


CATEGORIES = {"actions": "action", "concepts": "concept", "conventions": "convention"}
TABLE_ROW = re.compile(r"^\|\s*\[?`(?P<name>[a-z0-9-]+)`\]?(\([^)]*\))?\s*\|\s*(?P<use>.+?)\s*\|\s*$")


def skill_table(path: Path) -> dict[str, str]:
    """Read the first-column skill name and the use column of a skill table."""
    table: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        if match := TABLE_ROW.match(line):
            table[match.group("name")] = match.group("use")
    return table


def frontmatter(path: Path) -> dict[str, str | None]:
    """Return name, the metadata an-dr.* values, and the body of a SKILL.md."""
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    result: dict[str, str | None] = {"name": None, "type": None, "dependencies": None, "body": ""}
    if not lines or lines[0] != "---":
        return result
    in_metadata = False
    end = len(lines)
    for index in range(1, len(lines)):
        line = lines[index]
        if line == "---":
            end = index
            break
        if match := re.match(r"^name:\s*(\S+)", line):
            result["name"] = match.group(1)
        if line and not line[0].isspace():
            in_metadata = bool(re.match(r"^metadata:\s*$", line))
        if in_metadata and (match := re.match(r"^\s+an-dr\.dependencies:\s*(.+)$", line)):
            result["dependencies"] = match.group(1).strip()
        if in_metadata and (match := re.match(r"^\s+an-dr\.type:\s*(.+)$", line)):
            result["type"] = match.group(1).strip()
    if end + 1 < len(lines):
        result["body"] = "\n".join(lines[end + 1 :])
    return result


def dependency_cycles(graph: dict[str, list[str]]) -> list[str]:
    """One shortest cycle through each skill that lies on a cycle, deduplicated by rotation."""
    cycles: set[str] = set()
    for start in sorted(graph):
        found: list[str] | None = None
        queue: list[list[str]] = [[start]]
        seen = {start}
        while queue and found is None:
            path = queue.pop(0)
            for following in graph[path[-1]]:
                if following == start:
                    found = path
                    break
                if following not in seen and following in graph:
                    seen.add(following)
                    queue.append([*path, following])
        if found:
            smallest = min(found)
            rotate = found.index(smallest)
            ordered = found[rotate:] + found[:rotate]
            cycles.add(" -> ".join([*ordered, ordered[0]]))
    return sorted(cycles)


def own_category(category: str) -> bool:
    return category.startswith("_")


def check(root: Path, require_tests: bool = False) -> tuple[int, list[tuple[str, str]], list[str]]:
    skills_dir = root / "skills"
    problems: list[tuple[str, str]] = []

    def problem(where: str, what: str) -> None:
        problems.append((where, what))

    catalog = skill_table(skills_dir / "README.md")

    skill_paths: dict[str, tuple[str, Path]] = {}
    for category in sorted(path for path in skills_dir.iterdir() if path.is_dir()):
        if (category / "SKILL.md").is_file():
            problem(f"skills/{category.name}", "holds a SKILL.md directly; skills sit one level deeper, inside a category folder")
            continue
        if category.name not in CATEGORIES and not own_category(category.name):
            listed = ", ".join(CATEGORIES)
            problem(
                f"skills/{category.name}",
                f"is not a category folder; use {listed}, or a folder starting with '_' for the repository's own skills",
            )
            continue
        for directory in sorted(path for path in category.iterdir() if path.is_dir()):
            if directory.name in skill_paths:
                problem(directory.name, f"exists in both {skill_paths[directory.name][0]} and {category.name}")
                continue
            skill_paths[directory.name] = (category.name, directory)
    folders = sorted(skill_paths)

    for name in folders:
        if name not in catalog:
            problem(name, "missing from the skills/README.md table")
    for name in catalog:
        if name not in folders:
            problem(name, "listed in the skills/README.md table but has no folder")

    graph: dict[str, list[str]] = {}
    for name in folders:
        category, folder = skill_paths[name]
        skill_file = folder / "SKILL.md"
        where = f"skills/{category}/{name}/SKILL.md"
        if not skill_file.is_file():
            problem(f"skills/{category}/{name}", "has no SKILL.md")
            continue
        front = frontmatter(skill_file)
        if front["name"] != name:
            problem(where, f"frontmatter name is '{front['name']}'")

        kind = front["type"]
        if kind not in ("action", "concept", "convention"):
            problem(where, f"metadata an-dr.type is '{kind}'; use action, concept, or convention")
        else:
            folder_type = CATEGORIES.get(category)
            if folder_type and kind != folder_type:
                problem(where, f"is a {kind} but sits in {category}, which holds {folder_type}s")
            if not own_category(category):
                if kind == "concept" and not re.search(r"(^|-)concept-", name):
                    problem(where, "is a concept, so its name needs 'concept-'")
                if kind == "convention" and not re.search(r"(^|-)convention-", name):
                    problem(where, "is a convention, so its name needs 'convention-'")
            if kind == "concept":
                extra = [entry for entry in folder.iterdir() if entry.name not in ("SKILL.md", "README.md") and not (entry.name == "evals" and entry.is_dir())]
                if extra:
                    problem(where, f"is a concept and holds {extra[0].name}; a concept allows only SKILL.md, README.md, and evals/")

        if require_tests and not (folder / "evals" / "evals.json").is_file():
            problem(where, "missing evals/evals.json")
        if require_tests and not (folder / "evals" / "EVAL.md").is_file():
            problem(where, "missing evals/EVAL.md")

        raw = front["dependencies"]
        if raw is None:
            problem(where, "has no metadata an-dr.dependencies; declare the skills it names, or none, or PROHIBITED")
            continue
        declared = [] if raw in ("PROHIBITED", "none") else [part for part in re.split(r"\s+", raw) if part]
        for dependency in declared:
            if dependency not in folders:
                problem(where, f"declares dependency '{dependency}', which does not exist")
        graph[name] = [dependency for dependency in declared if dependency in folders]

        if not own_category(category):
            for dependency in graph[name]:
                if own_category(skill_paths[dependency][0]):
                    problem(where, f"depends on {dependency}, a skill of the repository itself; only skills in a '_' folder may")

        instructions = front["body"] or ""
        reference_dir = folder / "references"
        if reference_dir.is_dir():
            for reference in sorted(reference_dir.glob("*.md")):
                instructions += "\n" + reference.read_text(encoding="utf-8-sig")
        mentioned = [
            other
            for other in folders
            if other != name
            and re.search(rf"(`{re.escape(other)}`|<{re.escape(other)}>)", instructions, re.IGNORECASE)
        ]
        for other in mentioned:
            if raw == "PROHIBITED":
                problem(where, f"is PROHIBITED from depending on other skills but names {other}")
            elif other not in declared:
                problem(where, f"names {other} but does not declare it in dependencies")
        for dependency in declared:
            if dependency in folders and dependency not in mentioned:
                problem(where, f"declares {dependency} but never names it")

    cycles = dependency_cycles(graph)

    for file in sorted(root.rglob("*.md")):
        relative = file.relative_to(root).as_posix()
        if re.match(r"^(\.git|\.tmp-ai-gen|node_modules)/", relative):
            continue
        content = file.read_text(encoding="utf-8-sig", errors="replace")
        if re.search(r"(?<![<\w])agents/skills/", content) or "<clone>/skills/" in content:
            problem(relative, "uses a repository-layout path to a skill; write '<skill>/' or '<skill-name>/'")

    for suffix in ("*.py", "*.ps1", "*.psm1"):
        for file in sorted(root.rglob(suffix)):
            relative = file.relative_to(root).as_posix()
            if re.match(r"^(\.git|\.tmp-ai-gen)/", relative):
                continue
            if suffix != "*.py":
                problem(relative, "PowerShell file remains; port it to Python")
            elif not relative.startswith("skills/") and relative != "tests/run-all.py":
                problem(relative, "code outside skills/; skills must stay self-contained")

    return len(folders), problems, cycles


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", "-Root", type=Path, default=Path(__file__).resolve().parents[4])
    parser.add_argument("--fail-on-cycle", "-FailOnCycle", action="store_true")
    parser.add_argument("--require-tests", "-RequireTests", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    count, problems, cycles = check(root, args.require_tests)

    cycle_fails = args.fail_on_cycle and bool(cycles)
    if not problems:
        print(f"Registration check passed: {count} skills, the skill table and dependencies agree.")
        if cycles:
            print(f"\nDependency cycles ({len(cycles)}, shortest through each skill on one):\n")
            for cycle in cycles:
                print(f"- `{cycle}`")
        return 1 if cycle_fails else 0

    print(f"Registration check: {len(problems)} problem(s).\n")
    print("| Where | Problem |\n| --- | --- |")
    for where, what in problems:
        print(f"| `{where}` | {what.replace('|', '\\|')} |")
    if cycles:
        print(f"\nDependency cycles ({len(cycles)}, shortest through each skill on one):\n")
        for cycle in cycles:
            print(f"- `{cycle}`")
    return 1


if __name__ == "__main__":
    sys.exit(main())
