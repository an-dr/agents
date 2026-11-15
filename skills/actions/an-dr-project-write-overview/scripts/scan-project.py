"""Collect the evidence a project overview is built from.

Gathers language weight, manifests, entry points and container signals, tests,
CI, documentation with its staleness, churn hotspots, large files, marker
density, and author spread. Reports only; changes nothing.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path


EXCLUDED = re.compile(
    r"[\\/](\.git|node_modules|target|dist|build|out|bin|obj|vendor|\.venv|venv|__pycache__|\.next|\.tox|coverage|Pods|third_party)[\\/]"
)
EXCLUDED_DIRECTORIES = {
    ".git", "node_modules", "target", "dist", "build", "out", "bin", "obj", "vendor", ".venv", "venv",
    "__pycache__", ".next", ".tox", "coverage", "Pods", "third_party",
}
BINARY = re.compile(
    r"\.(png|jpe?g|gif|ico|svg|pdf|zip|gz|tar|7z|exe|dll|so|dylib|woff2?|ttf|eot|mp4|mp3|wav|bin|lock|snap|pyc|class|jar|db|sqlite3?)$"
)
MANIFEST = re.compile(
    r"(^|/)(package\.json|Cargo\.toml|pyproject\.toml|setup\.py|requirements[^/]*\.txt|go\.mod|composer\.json|Gemfile|pom\.xml|build\.gradle(\.kts)?|[^/]+\.csproj|[^/]+\.sln|pubspec\.yaml|mix\.exs|CMakeLists\.txt|Makefile)$"
)
CONTAINER = re.compile(
    r"(^|/)(Dockerfile[^/]*|docker-compose[^/]*\.ya?ml|Procfile|[^/]*\.tf|Chart\.yaml|skaffold\.ya?ml|serverless\.ya?ml|fly\.toml|vercel\.json|app\.ya?ml)$"
)
CONTAINER_FOLDER = re.compile(r"^(deploy|deployment|k8s|kubernetes|helm|infra|charts)/")
# A desktop application, a CLI, or a library deploys nothing and would
# otherwise report no containers at all. Its separately built units are
# declared binaries, packaging scripts, and installers instead.
PACKAGING = re.compile(
    r"(^|/)(tauri\.conf\.json|electron-builder\.ya?ml|[^/]*\.spec|[^/]*\.iss|[^/]*\.wxs|Info\.plist|[^/]*\.desktop|snapcraft\.ya?ml|flatpak[^/]*\.ya?ml|PKGBUILD|setup\.iss)$"
)
PACKAGING_SCRIPT = re.compile(r"(^|/)(dist|install|package|bundle|release)\.(ps1|sh|mjs|js|py)$")
ENTRY_POINT = re.compile(
    r"(^|/)(main|index|app|program|cli|server|__main__|Program)\.(ts|tsx|js|jsx|mjs|py|go|rs|rb|php|cs|java|kt|swift|c|cc|cpp)$"
)
ENTRY_FOLDER = re.compile(r"^(bin|cmd)/")
CI_WORKFLOW = re.compile(r"^\.github/workflows/.+\.ya?ml$")
CI_SINGLE_FILE = re.compile(r"^(\.gitlab-ci\.yml|azure-pipelines\.yml|\.travis\.yml|Jenkinsfile)$")
CI_FOLDER = re.compile(r"^\.circleci/")
TEST_FOLDER = re.compile(r"(^|/)(tests?|spec|__tests__)/")
TEST_SUFFIX = re.compile(r"(^|/)[^/]*(_test\.\w+|\.test\.\w+|\.spec\.\w+|Test\.java|Tests\.cs|_spec\.rb)$")
TEST_PREFIX = re.compile(r"(^|/)test_[^/]+\.py$")
CONFIGURATION = re.compile(r"(^|/)(\.env[^/]*|config[^/]*\.(json|ya?ml|toml|ini)|settings\.(py|json|ya?ml))$")
DOCUMENT = re.compile(r"\.(md|rst|adoc|txt)$")
DOCUMENT_EXCLUDED = re.compile(r"^(node_modules|CHANGELOG)")
INLINE_TEST = re.compile(r"#\[(cfg\(test\)|test)\]")
MARKER = re.compile(r"\b(TODO|FIXME|HACK|XXX|DEPRECATED)\b", re.IGNORECASE)
CARGO_BIN = re.compile(r"(?m)^\s*\[\[bin\]\]")
NPM_BIN = re.compile(r'"bin"\s*:')
PYTHON_SCRIPT = re.compile(r"\[project\.scripts\]")
AUTHOR = re.compile(r"^\s*(\d+)\s+(.+)$")
TWO_MEGABYTES = 2 * 1024 * 1024


def git(root: Path, *arguments: str) -> list[str]:
    """Run git inside the scanned repository, returning its lines or nothing."""
    result = subprocess.run(
        ["git", "-C", str(root), *arguments],
        capture_output=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    return result.stdout.splitlines() if result.returncode == 0 else []


def first_line(lines: list[str]) -> str | None:
    return lines[0] if lines else None


def relative_path(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def collect_files(root: Path) -> list[str]:
    found = []
    for directory, subdirectories, names in os.walk(root, onerror=lambda error: None, followlinks=False):
        subdirectories[:] = [name for name in subdirectories if name not in EXCLUDED_DIRECTORIES]
        for name in names:
            path = Path(directory) / name
            if EXCLUDED.search(str(path)):
                continue
            found.append(relative_path(path, root))
    # PowerShell's Sort-Object compares culture-aware and case-insensitively.
    return sorted(found, key=str.lower)


def extension_of(path: str) -> str:
    """Mirror .NET's Path.GetExtension: a leading dot is part of the extension, a trailing one is not."""
    name = Path(path).name
    index = name.rfind(".")
    if index < 0 or index == len(name) - 1:
        return "(none)"
    return name[index:].lower()


def measure_lines(path: Path) -> int:
    try:
        if path.stat().st_size > TWO_MEGABYTES:
            return 0
        return len(path.read_text(encoding="utf-8").splitlines())
    except (OSError, UnicodeDecodeError):
        return 0


def read_raw(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ""


def text_of(value: float | int) -> str:
    return format(value, ".15g")


def section(title: str) -> None:
    print()
    print(f"== {title}")


def print_table(rows: list[list[object]], columns: list[tuple[str, str]]) -> None:
    """Render the text table Format-Table prints, including its surrounding blank lines."""
    if not rows:
        print()
        return
    widths = [
        max(len(columns[index][0]), *(len(str(row[index])) for row in rows)) for index in range(len(columns))
    ]
    print()
    print(" ".join(name.ljust(widths[index]) for index, (name, _) in enumerate(columns)).rstrip())
    # Format-Table underlines the header text, then pads the rule out to the column width.
    print(" ".join(("-" * len(name)).ljust(widths[index]) for index, (name, _) in enumerate(columns)).rstrip())
    for row in rows:
        cells = []
        for index, (_, alignment) in enumerate(columns):
            text = str(row[index])
            cells.append(text.rjust(widths[index]) if alignment == "right" else text.ljust(widths[index]))
        print(" ".join(cells).rstrip())
    print()
    print()


def report(root: Path, top: int, churn_months: int) -> dict:
    is_repository = bool(git(root, "rev-parse", "--is-inside-work-tree"))

    paths = collect_files(root)

    languages: dict[str, dict] = {}
    line_count: dict[str, int] = {}
    for path in paths:
        if BINARY.search(path):
            continue
        extension = extension_of(path)
        lines = measure_lines(root / path)
        line_count[path] = lines
        language = languages.setdefault(extension, {"Extension": extension, "Files": 0, "Lines": 0})
        language["Files"] += 1
        language["Lines"] += lines
    language_table = sorted(languages.values(), key=lambda item: item["Lines"], reverse=True)[:top]

    manifests = [path for path in paths if MANIFEST.search(path)]
    container_signals = [path for path in paths if CONTAINER.search(path) or CONTAINER_FOLDER.search(path)]
    packaging_signals = [path for path in paths if PACKAGING.search(path) or PACKAGING_SCRIPT.search(path)]

    declared_binaries: list[str] = []
    for manifest in manifests:
        full = root / manifest
        if not full.is_file():
            continue
        text = read_raw(full)
        if not text:
            continue
        for _ in CARGO_BIN.finditer(text):
            declared_binaries.append(f"{manifest} (Cargo [[bin]])")
        if NPM_BIN.search(text):
            declared_binaries.append(f"{manifest} (npm bin)")
        if PYTHON_SCRIPT.search(text):
            declared_binaries.append(f"{manifest} (python script)")
    grouped: dict[str, int] = {}
    for binary in declared_binaries:
        grouped[binary] = grouped.get(binary, 0) + 1
    binaries = [f"{name} x{count}" for name, count in grouped.items()]

    entry_points = [path for path in paths if ENTRY_POINT.search(path) or ENTRY_FOLDER.search(path)]
    ci_files = [
        path for path in paths if CI_WORKFLOW.search(path) or CI_SINGLE_FILE.search(path) or CI_FOLDER.search(path)
    ]
    test_files = [
        path for path in paths if TEST_FOLDER.search(path) or TEST_SUFFIX.search(path) or TEST_PREFIX.search(path)
    ]
    config_files = [path for path in paths if CONFIGURATION.search(path)]
    test_lookup = {path.lower() for path in test_files}
    source_files = [path for path in paths if not BINARY.search(path) and path.lower() not in test_lookup]
    test_ratio = round(len(test_files) / len(source_files), 3) if source_files else 0
    # Rust keeps unit tests inside the source file, so a test-file count alone reads as untested.
    inline_test_files = [
        path for path in source_files if path.endswith(".rs") and INLINE_TEST.search(read_raw(root / path))
    ]

    doc_files = [path for path in paths if DOCUMENT.search(path) and not DOCUMENT_EXCLUDED.search(path)]
    repository_last_commit = None
    if is_repository:
        stamp = git(root, "log", "-1", "--format=%cI")
        if stamp:
            repository_last_commit = datetime.fromisoformat(stamp[0])
    documents = []
    for document in doc_files:
        last_edit = None
        if is_repository:
            stamp = git(root, "log", "-1", "--format=%cI", "--", document)
            if stamp and stamp[0]:
                last_edit = datetime.fromisoformat(stamp[0])
        if last_edit and repository_last_commit:
            age_days = int((repository_last_commit - last_edit).total_seconds() / 86400)
        else:
            age_days = -1
        documents.append(
            {
                "Path": document,
                "LastEdit": last_edit.strftime("%Y-%m-%d") if last_edit else "unknown",
                "StaleDays": age_days,
            }
        )
    documents.sort(key=lambda item: item["StaleDays"], reverse=True)

    churn = []
    if is_repository:
        touched = git(root, "log", f"--since={churn_months} months ago", "--name-only", "--pretty=format:")
        counts: dict[str, int] = {}
        for line in touched:
            if not line:
                continue
            if EXCLUDED.search(line) or BINARY.search(line):
                continue
            counts[line] = counts.get(line, 0) + 1
        churn = [
            {"Path": path, "Commits": commits, "Lines": line_count.get(path, 0)}
            for path, commits in sorted(counts.items(), key=lambda item: item[1], reverse=True)[:top]
        ]

    largest = [
        {"Path": path, "Lines": lines}
        for path, lines in sorted(
            ((path, lines) for path, lines in line_count.items() if path.lower() not in test_lookup),
            key=lambda item: item[1],
            reverse=True,
        )[:top]
    ]

    marker_counts: dict[str, int] = {}
    for path in paths:
        full = root / path
        try:
            size = full.stat().st_size
        except OSError:
            continue
        if EXCLUDED.search(str(full)) or BINARY.search(full.name) or size > TWO_MEGABYTES:
            continue
        try:
            text = full.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        matches = sum(1 for line in text.splitlines() if MARKER.search(line))
        if matches:
            marker_counts[path] = matches
    markers = [
        {"Path": path, "Markers": count}
        for path, count in sorted(marker_counts.items(), key=lambda item: item[1], reverse=True)[:top]
    ]

    authors = []
    if is_repository:
        for line in git(root, "shortlog", "-sne", "--all", "HEAD"):
            match = AUTHOR.match(line)
            if match:
                authors.append({"Commits": int(match.group(1)), "Author": match.group(2)})
        authors = authors[:top]

    head = first_line(git(root, "rev-parse", "--short", "HEAD")) if is_repository else None
    branch = first_line(git(root, "rev-parse", "--abbrev-ref", "HEAD")) if is_repository else None
    first_commit = first_line(git(root, "log", "--reverse", "--format=%cs")) if is_repository else None
    total_commits = first_line(git(root, "rev-list", "--count", "HEAD")) if is_repository else None
    total_lines = float(sum(line_count.values()))

    print(f"Project scan: {root}")
    print(
        f"commit {head or 'n/a'} on {branch or 'n/a'}; {total_commits or '?'} commits since {first_commit or '?'}; "
        f"{len(paths)} files, {text_of(total_lines)} lines"
    )

    section("Languages")
    print_table(
        [[row["Extension"], row["Files"], row["Lines"]] for row in language_table],
        [("Extension", "left"), ("Files", "right"), ("Lines", "right")],
    )

    section("Manifests")
    for path in manifests:
        print(f"  {path}")
    section("Container signals")
    if container_signals:
        for path in container_signals:
            print(f"  {path}")
    else:
        print("  none found (a desktop app, CLI, or library deploys nothing -- read the packaging signals instead)")
    section("Packaging and declared binaries")
    if packaging_signals or binaries:
        for path in packaging_signals:
            print(f"  {path}")
        for binary in binaries:
            print(f"  {binary}")
    else:
        print("  none found")
    section("Entry points")
    if entry_points:
        for path in entry_points[:top]:
            print(f"  {path}")
    else:
        print("  none found")
    section("CI")
    if ci_files:
        for path in ci_files:
            print(f"  {path}")
    else:
        print("  none found")
    section("Configuration")
    if config_files:
        for path in config_files[:top]:
            print(f"  {path}")
    else:
        print("  none found")
    section("Tests")
    print(f"  {len(test_files)} test files against {len(source_files)} source files (ratio {text_of(test_ratio)})")
    if inline_test_files:
        print(f"  {len(inline_test_files)} source files with inline test modules")

    section("Documentation by staleness (days behind the last commit)")
    print_table(
        [[row["Path"], row["LastEdit"], row["StaleDays"]] for row in documents[:top]],
        [("Path", "left"), ("LastEdit", "left"), ("StaleDays", "right")],
    )

    section(f"Churn hotspots (last {churn_months} months)")
    if churn:
        print_table(
            [[row["Path"], row["Commits"], row["Lines"]] for row in churn],
            [("Path", "left"), ("Commits", "right"), ("Lines", "right")],
        )
    else:
        print("  no history available")

    section("Largest source files")
    print_table(
        [[row["Path"], row["Lines"]] for row in largest],
        [("Path", "left"), ("Lines", "right")],
    )

    section("Marker density")
    if markers:
        print_table(
            [[row["Path"], row["Markers"]] for row in markers],
            [("Path", "left"), ("Markers", "right")],
        )
    else:
        print("  none found")

    section("Authors")
    if authors:
        print_table(
            [[row["Commits"], row["Author"]] for row in authors],
            [("Commits", "right"), ("Author", "left")],
        )
    else:
        print("  no history available")

    print()
    print("Read the churn list and the stale documents first: drift and risk concentrate there.")

    return {
        "root": str(root),
        "head": head,
        "branch": branch,
        "commits": total_commits,
        "firstCommit": first_commit,
        "files": len(paths),
        "lines": total_lines,
        "languages": language_table,
        "manifests": manifests,
        "containerSignals": container_signals,
        "entryPoints": entry_points,
        "packaging": packaging_signals,
        "binaries": binaries,
        "ci": ci_files,
        "configuration": config_files,
        "tests": {
            "files": len(test_files),
            "inline": len(inline_test_files),
            "sources": len(source_files),
            "ratio": test_ratio,
        },
        "documents": documents,
        "churn": churn,
        "largest": largest,
        "markers": markers,
        "authors": authors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--path", "-Path", type=Path, default=Path("."))
    parser.add_argument("--json", "-Json")
    parser.add_argument("--top", "-Top", type=int, default=15)
    parser.add_argument("--churn-months", "-ChurnMonths", type=int, default=12)
    args = parser.parse_args()
    if not args.path.exists():
        print(f"Path '{args.path}' does not exist.", file=sys.stderr)
        return 1
    root = args.path.resolve()
    report_data = report(root, args.top, args.churn_months)
    if args.json:
        try:
            Path(args.json).write_text(json.dumps(report_data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        except OSError as error:
            print(error, file=sys.stderr)
            return 1
        print(f"JSON report written to {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
