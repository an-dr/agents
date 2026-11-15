"""Check every SKILL.md against the Agent Skills format and agent-skill.

Checks for only the standard frontmatter keys, a valid name and description,
string-valued metadata, a space-separated allowed-tools, the an-dr.type and
an-dr.dependencies extensions, a description that ends in a trigger sentence,
one title that matches the skill's type, the section order for that type, and
that every reference file is linked and every linked reference exists. Warns on
a SKILL.md or reference file over the token budget, a description over the
length budget, and a command block in a concept or convention. Prints Markdown
tables of warnings and problems, and exits 1 when there are problems.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


MAX_TOKENS = 1500
MAX_DESCRIPTION = 300
MAX_BODY_LINES = 200
STANDARD_KEYS = ("name", "description", "license", "compatibility", "metadata", "allowed-tools")


def tokens(text: str) -> int:
    return round(len(text) / 4)


def check(root: Path) -> tuple[int, list[tuple[str, str]], list[tuple[str, str]]]:
    skills_dir = root / "skills"
    problems: list[tuple[str, str]] = []
    warnings: list[tuple[str, str]] = []

    def problem(where: str, what: str) -> None:
        problems.append((where, what))

    def warning(where: str, what: str) -> None:
        warnings.append((where, what))

    checked = 0
    for file in sorted(skills_dir.glob("*/*/SKILL.md")):
        if not (file.parent / "README.md").is_file():
            problem(file.parent.name, "README.md is missing; see references/readme.md.")
        name = file.parent.name
        checked += 1
        where = f"skills/{file.parent.parent.name}/{name}/SKILL.md"
        lines = file.read_text(encoding="utf-8-sig").splitlines()

        keys: dict[str, str] = {}
        metadata: dict[str, str] = {}
        body_start = 0
        in_metadata = False
        if lines and lines[0] == "---":
            for index in range(1, len(lines)):
                line = lines[index]
                if line == "---":
                    body_start = index + 1
                    break
                if match := re.match(r"^([^\s:][^:]*):\s*(.*)$", line):
                    keys[match.group(1)] = match.group(2)
                    in_metadata = match.group(1) == "metadata"
                elif in_metadata and (match := re.match(r"^  ([^\s:][^:]*):\s*(.+)$", line)):
                    metadata[match.group(1)] = match.group(2)
                elif in_metadata and line.strip():
                    problem(where, f"metadata line '{line.strip()}' is not a flat key: value pair")
        else:
            problem(where, "has no frontmatter")

        for key in keys:
            if key not in STANDARD_KEYS:
                problem(where, f"frontmatter key '{key}' is not part of the Agent Skills format; put extensions under metadata")
        if keys.get("name") != name:
            problem(where, f"frontmatter name '{keys.get('name', '')}' does not match its folder")
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name) or len(name) > 64:
            problem(where, "name must be 1-64 lowercase letters, digits, and single hyphens")
        if "allowed-tools" in keys and re.search(r"[,\[\]]", keys["allowed-tools"]):
            problem(where, "allowed-tools must be a space-separated string, without commas or brackets")
        if not keys.get("license"):
            problem(where, "has no license")
        if "version" in metadata and not re.fullmatch(r'"?\d+\.\d+\.\d+"?', metadata["version"]):
            problem(where, 'metadata version must be a semantic version such as "1.0.0"')
        for required in ("author", "version", "an-dr.type", "an-dr.dependencies"):
            if required not in metadata:
                problem(where, f"metadata has no {required}")
        for key, value in metadata.items():
            if re.match(r"^[\[{|>]", value):
                problem(where, f"metadata {key} must be a plain string, not a list or map")

        description = keys.get("description")
        if not description:
            problem(where, "has no one-line description")
        else:
            if ": " in description or " #" in description:
                problem(where, "description contains ': ' or ' #', which is invalid in an unquoted YAML value; use a dash or rephrase")
            if len(description) > 1024:
                problem(where, f"description is {len(description)} characters; the limit is 1024")
            elif len(description) > MAX_DESCRIPTION:
                warning(where, f"description is {len(description)} characters; the budget is {MAX_DESCRIPTION}")
            if not re.match(r"^[A-Z]", description):
                problem(where, "description does not start with a capital letter")
            if not re.search(r"(^|[.;] )Use [a-z]", description):
                problem(where, "description has no trigger sentence beginning 'Use '")
            sentences = len(re.findall(r"[.!?](\s|$)", description))
            if sentences > 2:
                warning(where, f"description has {sentences} sentences; size.md allows two")

        text = "\n".join(lines)
        kind_for_commands = metadata.get("an-dr.type", "action")
        if kind_for_commands in ("concept", "convention") and re.search(r"(?m)^```(?:sh|powershell)$", text):
            warning(where, f"a {kind_for_commands} contains a command to run; it only describes, and running belongs to an action")
        token_count = tokens(text)
        if token_count > MAX_TOKENS:
            warning(where, f"is about {token_count} tokens; the budget is {MAX_TOKENS}, so move branch material into references/")
        body_lines = len(lines) - body_start
        if body_lines > MAX_BODY_LINES:
            warning(where, f"body is {body_lines} lines; size.md keeps it under {MAX_BODY_LINES}")

        fenced = False
        after_title = False
        for index in range(body_start, len(lines)):
            line = lines[index]
            if line.startswith("```"):
                fenced = not fenced
                continue
            if fenced:
                continue
            if line.startswith("# "):
                after_title = True
                continue
            if after_title and line.strip():
                if not re.match(r"^(#|[-*|>]|\d+\.|[A-Z][\w -]{0,30}: )", line):
                    warning(where, "opens with an intro paragraph; size.md allows only rules or a Defers: line under the title")
                after_title = False
            if re.match(r"^\s*[-*] \*\*[^*]+\.\*\* ", line):
                warning(where, f"line {index + 1} leads with a bold rule name; size.md asks for plain one-rule lines")
                break

        skill_where = f"skills/{file.parent.parent.name}/{name}"
        prose = re.sub(r"`[^`\n]*`", "", text)
        for match in re.finditer(r"\]\((references/[^)#\s]+)", prose):
            target = file.parent / match.group(1)
            if not target.is_file():
                problem(where, f"links {match.group(1)}, which does not exist")
        reference_dir = file.parent / "references"
        if reference_dir.is_dir():
            for reference in sorted(reference_dir.rglob("*.md")):
                relative = "references/" + reference.relative_to(reference_dir).as_posix()
                if f"]({relative}" not in prose:
                    problem(f"{skill_where}/{relative}", "is not linked from SKILL.md, so no agent reads it")
                reference_tokens = tokens(reference.read_text(encoding="utf-8-sig"))
                if reference_tokens > MAX_TOKENS:
                    warning(f"{skill_where}/{relative}", f"is about {reference_tokens} tokens; the budget is {MAX_TOKENS}")

        kind = metadata.get("an-dr.type", "action")

        titles: list[str] = []
        sections: list[str] = []
        in_fence = False
        for index in range(body_start, len(lines)):
            if lines[index].startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            if match := re.match(r"^# (.+)$", lines[index]):
                titles.append(match.group(1))
            elif match := re.match(r"^## (.+)$", lines[index]):
                sections.append(match.group(1))

        if len(titles) != 1:
            problem(where, f"has {len(titles)} top-level titles; it needs exactly one")
        elif kind == "concept" and not re.match(r"^Concept: ", titles[0]):
            problem(where, f"title '{titles[0]}' must start with 'Concept: '")
        elif kind == "convention" and not re.match(r"^Convention: ", titles[0]):
            problem(where, f"title '{titles[0]}' must start with 'Convention: '")
        elif kind == "action" and re.match(r"^(Concept|Convention): ", titles[0]):
            problem(where, f"title '{titles[0]}' uses a concept or convention prefix on an action")

        last = sections[-1] if sections else ""
        if kind == "action":
            if "Rules" in sections and last != "Rules":
                problem(where, f"'## Rules' must be the last section, not '## {last}'")
            if "Output" in sections and "Rules" in sections and sections.index("Output") > sections.index("Rules"):
                problem(where, "'## Output' must come before '## Rules'")
        elif kind == "concept":
            if "Violations" not in sections:
                problem(where, "has no '## Violations' section")
        elif kind == "convention":
            if "Examples" in sections and last != "Examples":
                problem(where, f"'## Examples' must be the last section, not '## {last}'")
            if "Check" in sections and "Examples" in sections and sections.index("Check") > sections.index("Examples"):
                problem(where, "'## Check' must come before '## Examples'")

    return checked, problems, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", "-Root", type=Path, default=Path(__file__).resolve().parents[4])
    args = parser.parse_args()
    checked, problems, warnings = check(args.root.resolve())

    if warnings:
        print(f"Size warnings: {len(warnings)}. They do not fail the check.\n")
        print("| Where | Warning |\n| --- | --- |")
        for where, what in warnings:
            print(f"| `{where}` | {what} |")
        print()
    if not problems:
        print(f"Skill check passed: {checked} skills follow the Agent Skills format and agent-skill.")
        return 0
    print(f"Skill check: {len(problems)} problem(s).\n")
    print("| Where | Problem |\n| --- | --- |")
    for where, what in problems:
        print(f"| `{where}` | {what.replace('|', '\\|')} |")
    return 1


if __name__ == "__main__":
    sys.exit(main())
