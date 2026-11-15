"""Build or check the Mermaid graph of declared skill dependencies."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


BEGIN = "<!-- skill-dependencies begin -->"
END = "<!-- skill-dependencies end -->"


@dataclass(frozen=True)
class Skill:
    name: str
    category: str
    dependencies: tuple[str, ...] | None


def dependencies(path: Path) -> tuple[str, ...] | None:
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    in_metadata = False
    for line in lines[1:]:
        if line == "---":
            break
        if line and not line[0].isspace():
            in_metadata = bool(re.fullmatch(r"metadata:\s*", line))
        if in_metadata and (match := re.fullmatch(r"\s+an-dr\.dependencies:\s*(.+)", line)):
            value = match.group(1).strip()
            return () if value in ("none", "PROHIBITED") else tuple(value.split())
    return None


def graph(root: Path) -> tuple[str, list[Skill], list[Skill], list[str], int]:
    skills = [Skill(path.parent.name, path.parent.parent.name, dependencies(path)) for path in sorted(root.glob("skills/*/*/SKILL.md"))]
    if not skills:
        raise ValueError(f"No skills found under {root}/skills/<category>/<name>/SKILL.md.")
    known = {skill.name for skill in skills}
    undeclared = [skill for skill in skills if skill.dependencies is None]
    unknown = [f"{skill.name} -> {name}" for skill in skills for name in (skill.dependencies or ()) if name not in known]
    lines = ["```mermaid", "flowchart LR", "    %% diagram-budget: exempt generated reference graph of every skill"]
    for category in sorted({skill.category for skill in skills}):
        title = category.lstrip("_").replace("-", " ").capitalize()
        identifier = "g_" + re.sub(r"[^A-Za-z0-9]", "_", category.lstrip("_"))
        lines.append(f'    subgraph {identifier}["{title}"]')
        lines.extend(f"        {skill.name}" for skill in skills if skill.category == category)
        lines.append("    end")
    for skill in skills:
        valid = [name for name in (skill.dependencies or ()) if name in known]
        if valid:
            lines.append(f"    {skill.name} --> {' & '.join(valid)}")
    if undeclared:
        lines.extend(("    classDef undeclared stroke-dasharray: 5 3", "    class " + ",".join(skill.name for skill in undeclared) + " undeclared"))
    lines.append("```")
    arrows = sum(len(skill.dependencies or ()) for skill in skills)
    return "\n".join(lines), skills, undeclared, unknown, arrows


def summary(skills: list[Skill], undeclared: list[Skill], unknown: list[str], arrows: int) -> None:
    print(f"Dependency graph: {len(skills)} skills, {arrows} arrows.")
    if undeclared:
        print(f"\nSkills without an-dr.dependencies ({len(undeclared)}), drawn dashed:\n")
        for skill in undeclared:
            print(f"- `{skill.name}`")
    if unknown:
        print("\nDeclared dependencies that match no skill:\n")
        for item in unknown:
            print(f"- `{item}`")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", "-Root", type=Path, default=Path(__file__).resolve().parents[4])
    parser.add_argument("--markdown", "-Markdown", type=Path)
    parser.add_argument("--check", "-Check", action="store_true")
    args = parser.parse_args()
    try:
        diagram, skills, undeclared, unknown, arrows = graph(args.root.resolve())
        if not args.markdown:
            print(diagram + "\n")
            summary(skills, undeclared, unknown, arrows)
            return 1 if args.check and (undeclared or unknown) else 0
        target = args.markdown.resolve(strict=True)
        original = target.read_text(encoding="utf-8-sig")
        pattern = re.compile(re.escape(BEGIN) + r"[\s\S]*?" + re.escape(END))
        if not pattern.search(original):
            raise ValueError(f"{target} has no '{BEGIN}' ... '{END}' block; add the two markers where the diagram belongs.")
        block = f"{BEGIN}\n\n{diagram}\n\n{END}"
        updated = pattern.sub(lambda _: block, original)
        if args.check:
            stale = updated != original
            if stale:
                print(f"The diagram in {target} is stale; run this script with --markdown to rebuild it.")
            summary(skills, undeclared, unknown, arrows)
            if stale or undeclared or unknown:
                return 1
            print(f"The diagram in {target} is current.")
            return 0
        if updated != original:
            target.write_text(updated, encoding="utf-8")
        print(f"Rebuilt the dependency diagram in {target}.")
        summary(skills, undeclared, unknown, arrows)
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
