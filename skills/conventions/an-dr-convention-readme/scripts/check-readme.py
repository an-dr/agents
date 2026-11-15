"""Report the repository evidence a README may rely on and the claims it makes.

Lists the evidence found, then every README claim the evidence does not
support, then the README's Markdown format through the markdown skill's
checker. Exits non-zero on a contradiction, an unresolved link, or a Markdown
format error.
"""

from __future__ import annotations

import argparse
import math
import os
import re
import subprocess
import sys
from pathlib import Path


EXCLUDED = re.compile(r"[\\/](?:\.git|node_modules|target|dist|build|vendor|\.venv|__pycache__)[\\/]", re.IGNORECASE)
FENCE = re.compile(r"^\s*```")
HEADING = re.compile(r"^(#{1,6})\s+(.+?)\s*$")
LICENSE = re.compile(r"(?:LICENSE|LICENCE|COPYING)(?:\.\w+)?", re.IGNORECASE)
MANIFEST = re.compile(
    r"^[^/]*(?:package\.json|Cargo\.toml|pyproject\.toml|setup\.py|go\.mod|composer\.json|Gemfile|pom\.xml|"
    r"build\.gradle(?:\.kts)?|.*\.csproj)$",
    re.IGNORECASE,
)
CI = re.compile(
    r"^\.github/workflows/.+\.ya?ml$|^(?:\.gitlab-ci\.yml|azure-pipelines\.yml|\.travis\.yml|Jenkinsfile)$|^\.circleci/",
    re.IGNORECASE,
)
TESTS = re.compile(
    r"(?:^|/)(?:tests?|spec|__tests__)/|(?:^|/)[^/]*(?:_test\.\w+|\.test\.\w+|\.spec\.\w+|Test\.java|Tests\.cs)$|"
    r"(?:^|/)test_[^/]+\.py$",
    re.IGNORECASE,
)
WORKSPACE = re.compile(r"^(?:packages|apps|crates|services)/", re.IGNORECASE)
IMAGES = re.compile(r"\.(?:png|gif|jpe?g|svg|webp)$", re.IGNORECASE)
COMMAND = re.compile(r"^(?:bin|cmd)/|(?:^|/)cli\.\w+$", re.IGNORECASE)
TEST_INSTRUCTIONS = re.compile(r"(?m)^.*\b(?:run the tests|npm test|pytest|cargo test|go test|dotnet test)\b.*$", re.IGNORECASE)
BADGE_WORKFLOW = re.compile(r"actions/workflows/([A-Za-z0-9._-]+\.ya?ml)/badge\.svg")
CI_BADGE = re.compile(r"!\[[^\]]*\]\([^)]*(?:build|ci|workflow|travis|circleci)[^)]*\)", re.IGNORECASE)
LINK = re.compile(r"\]\(([^)\s]+)")
REMOTE_LINK = re.compile(r"^(?:https?:|mailto:|#|<)", re.IGNORECASE)
TOC = re.compile(r"(?m)^#{1,3}\s*(?:table of contents|contents)\s*$", re.IGNORECASE)
DEVELOPMENT = re.compile(r"(?m)^#{2,3}.*development", re.IGNORECASE)
REPOSITORY_MAP = re.compile(r"(?m)^#{2,3}.*(?:repository (?:map|layout)|project structure|packages)", re.IGNORECASE)
ADR_MENTION = re.compile(r"adr|decision", re.IGNORECASE)
IMAGE_USE = re.compile(r"!\[")

# Baseline sections, in the order the skill requires them.
BASELINE = {
    "why": r"why|about|overview|problem|motivat|rationale",
    "install": r"install|setup|getting.started|prerequisit",
    "usage": r"usage|quick.?start|example|how.to.use",
    "features": r"feature|capabilit|what.it.does",
    "configuration": r"config|settings|options|environment",
    "documentation": r"document|^docs$|reference|learn.more",
    "contributing": r"contribut|development|hacking",
    "license": r"licen[cs]e",
    "status": r"status|maintenance|project.state|stability|roadmap",
}

def repository_files(root: Path, depth: int = 3) -> list[Path]:
    """List repository files, skipping dependency and build directories."""
    found: list[Path] = []
    for current, directories, names in os.walk(root, onerror=lambda error: None):
        level = len(Path(current).relative_to(root).parts)
        for name in names:
            path = Path(current) / name
            if not EXCLUDED.search(str(path)):
                found.append(path)
        if level >= depth:
            directories.clear()
    return sorted(found, key=lambda path: os.path.normcase(str(path)))


def any_path(root: Path, candidates: list[str]) -> bool:
    """Report whether any of the given repository-relative paths exists."""
    return any((root / candidate).exists() for candidate in candidates)


def read_lines(path: Path) -> list[str]:
    """Split a file into lines on the same terminators the original used."""
    text = path.read_bytes().decode("utf-8-sig", errors="replace")
    lines = re.split(r"\r\n|\r|\n", text)
    if lines and lines[-1] == "":
        lines.pop()
    return lines


def git(root: Path, arguments: list[str]) -> subprocess.CompletedProcess:
    """Run one git command inside the repository."""
    return subprocess.run(["git", "-C", str(root), *arguments], capture_output=True, text=True, check=False)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", "-Path", type=Path, default=Path("."))
    parser.add_argument("--readme", "-Readme", default="README.md")
    parser.add_argument("--markdown-skill", "-MarkdownSkill", type=Path, required=True)
    args = parser.parse_args()
    findings: list[tuple[str, str, int, str]] = []

    def add(severity: str, rule: str, detail: str, line: int = 0) -> None:
        findings.append((severity, rule, line, detail))

    try:
        root = args.path.resolve(strict=True)
    except OSError as error:
        print(error, file=sys.stderr)
        return 1

    files = repository_files(root)
    names = [path.name for path in files]
    relative = [path.relative_to(root).as_posix() for path in files]

    # ---- evidence ---------------------------------------------------------

    license_file = next((name for name in names if LICENSE.fullmatch(name)), None)
    manifests = [path for path in relative if MANIFEST.search(path)]
    ci_files = [path for path in relative if CI.search(path)]
    test_evidence = [path for path in relative if TESTS.search(path)]
    docs_directory = any_path(root, ["docs", "doc"])
    adr_directory = any_path(root, ["docs/adr", "docs/decisions", "adr"])
    contributing = any_path(root, ["CONTRIBUTING.md", "CONTRIBUTING", ".github/CONTRIBUTING.md"])
    code_of_conduct = any_path(root, ["CODE_OF_CONDUCT.md", ".github/CODE_OF_CONDUCT.md"])
    workspace = [path for path in relative if WORKSPACE.search(path)]
    images = [path for path in relative if IMAGES.search(path)]
    cli_hints = [path for path in relative if COMMAND.search(path)]

    commit_count = 0
    is_repository = git(root, ["rev-parse", "--is-inside-work-tree"]).returncode == 0
    if is_repository:
        count = git(root, ["rev-list", "--count", "HEAD"])
        count_text = "".join(count.stdout.splitlines()).strip()
        if count.returncode == 0 and count_text:
            commit_count = int(count_text)

    packages = {path.split("/")[1] for path in workspace}
    print("Evidence:")
    evidence = {
        "manifests": ", ".join(manifests) if manifests else "none",
        "license file": license_file or "none",
        "CI config": ", ".join(ci_files) if ci_files else "none",
        "tests": f"{len(test_evidence)} file(s)" if test_evidence else "none",
        "docs directory": "yes, with ADRs" if adr_directory else "yes" if docs_directory else "none",
        "contributing": "yes" if contributing else "none",
        "code of conduct": "yes" if code_of_conduct else "none",
        "sub-packages": f"yes ({len(packages)})" if workspace else "none",
        "command entry": ", ".join(cli_hints) if cli_hints else "none",
        "images": f"{len(images)}" if images else "none",
        "commits": commit_count if is_repository else "not a Git repository",
    }
    for key, value in evidence.items():
        print(f"  {key:<16} {value}")

    # ---- the README itself ------------------------------------------------

    readme_path = root / args.readme
    if not readme_path.exists():
        print()
        print(f"No {args.readme} exists. Write one from the evidence above.")
        return 0

    lines = read_lines(readme_path)
    in_fence = False
    headings: list[tuple[int, str, int]] = []
    for index, line in enumerate(lines):
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        heading = HEADING.match(line)
        if heading:
            headings.append((len(heading.group(1)), heading.group(2), index + 1))

    found: dict[str, tuple[int, str, int] | None] = {key: None for key in BASELINE}
    for heading in headings:
        for key, pattern in BASELINE.items():
            if found[key] is None and re.search(pattern, heading[1], re.IGNORECASE):
                found[key] = heading

    body = "\n".join(lines)

    # Claims the repository does not support.
    if found["license"] and not license_file:
        add(
            "error",
            "claim.license",
            "The README has a license section but the repository has no LICENSE file. Report the gap instead of naming a license.",
            found["license"][2],
        )
    if not test_evidence and TEST_INSTRUCTIONS.search(body):
        add("error", "claim.tests", "The README explains how to run tests, but no test files were found.")
    for match in BADGE_WORKFLOW.finditer(body):
        workflow = f".github/workflows/{match.group(1)}"
        if not any_path(root, [workflow]):
            add("error", "badge.workflow", f"A build badge points at '{workflow}', which does not exist.")
    if not ci_files and CI_BADGE.search(body):
        add("warning", "badge.ci", "The README shows a build badge, but the repository has no CI configuration.")

    # Links that do not resolve.
    in_fence = False
    for index, line in enumerate(lines):
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        for match in LINK.finditer(line):
            target = match.group(1)
            if REMOTE_LINK.search(target):
                continue
            cleaned = target.split("#")[0]
            if not cleaned:
                continue
            if not (readme_path.parent / cleaned).exists():
                add("error", "link.broken", f"The link target '{cleaned}' does not resolve.", index + 1)

    # Redundancy and shape.
    groups: dict[str, list[tuple[int, str, int]]] = {}
    for heading in headings:
        groups.setdefault(heading[1].lower(), []).append(heading)
    for group in groups.values():
        if len(group) < 2:
            continue
        where = ", ".join(str(heading[2]) for heading in group)
        add(
            "warning",
            "content.duplicate",
            f"The heading '{group[0][1]}' appears {len(group)} times (lines {where}). One of them is redundant.",
            group[0][2],
        )
    if not any(level == 1 for level, _, _ in headings):
        add("warning", "structure.title", "The README has no title heading.")

    screens = math.ceil(len(lines) / 45)
    has_toc = bool(TOC.search(body))
    if screens > 4 and not has_toc:
        add("warning", "structure.toc", f"The README runs about {screens} screens and has no table of contents.")
    if screens <= 4 and has_toc:
        add("warning", "structure.toc", f"The README is about {screens} screens; a table of contents is noise at that length.")

    for key in BASELINE:
        if found[key]:
            continue
        if key == "license" and not license_file:
            add("warning", "gap.license", "No license section and no LICENSE file. Raise the missing license with the user.")
            continue
        add("warning", f"missing.{key}", f"The baseline '{key}' section is absent.")

    previous_line = 0
    previous_key = ""
    for key in BASELINE:
        heading = found[key]
        if not heading:
            continue
        if heading[2] < previous_line:
            add(
                "warning",
                "structure.order",
                f"'{key}' comes after '{previous_key}' in the file but before it in the baseline order.",
                heading[2],
            )
        previous_line = heading[2]
        previous_key = key

    # Conditional modules the evidence supports but the README omits.
    if test_evidence and not found["contributing"] and not DEVELOPMENT.search(body):
        add("note", "module.development", "The repository has tests but the README never says how to run them.")
    if workspace and not REPOSITORY_MAP.search(body):
        add("note", "module.map", "The repository has sub-packages but the README has no repository map.")
    if adr_directory and not ADR_MENTION.search(body):
        add("note", "module.adr", "The repository records ADRs that the README never links to.")
    if images and not IMAGE_USE.search(body):
        add("note", "module.screenshot", "The repository contains images that the README never shows.")

    # ---- markdown format (markdown) ---------------------------------------

    markdown_checker = args.markdown_skill / "scripts" / "check-markdown.py"
    print()
    if markdown_checker.is_file():
        print("Markdown format (markdown):")
        result = subprocess.run(
            [sys.executable, str(markdown_checker), str(readme_path)], capture_output=True, check=False
        )
        for line in result.stdout.decode("utf-8", errors="replace").splitlines():
            print(f"  {line}")
        markdown_failed = result.returncode != 0
    else:
        print(f"Markdown format not checked: -MarkdownSkill has no {markdown_checker}.")
        markdown_failed = True

    # ---- report -----------------------------------------------------------

    print()
    if not findings:
        print(f"{args.readme} matches the repository evidence and the baseline structure.")
        return 1 if markdown_failed else 0

    rank = {"error": 0, "warning": 1, "note": 2}
    for severity, rule, line, detail in sorted(findings, key=lambda finding: (rank[finding[0]], finding[2])):
        print(f"  {severity:<7} line {line:<4} {rule:<22} {detail}")

    error_count = sum(1 for finding in findings if finding[0] == "error")
    print()
    print(f"{len(findings)} finding(s), {error_count} blocking.")
    return 1 if error_count or markdown_failed else 0


if __name__ == "__main__":
    sys.exit(main())
