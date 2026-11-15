"""Check tracked files against the shared repository layout rules."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path


LICENSE = re.compile(r"^(?:LICENSE|LICENCE|COPYING)(?:\.\w+)?$")
GENERATED = re.compile(r"^((?:[^/]+/)*?(?:\.artifacts|code-review|\.tmp-ai-gen|__pycache__))/")


def findings(root: Path) -> list[tuple[str, str, str, str]]:
    result = subprocess.run(["git", "-C", str(root), "ls-files"], capture_output=True, text=True, check=False)
    if result.returncode:
        raise ValueError(f"Not a git repository: {root}")
    tracked = result.stdout.splitlines()
    found: list[tuple[str, str, str, str]] = []
    root_files = {path for path in tracked if "/" not in path}
    if "README.md" not in root_files:
        found.append(("error", "root-file", "README.md", "Every repository has README.md at the root."))
    if not any(LICENSE.fullmatch(path) for path in root_files):
        found.append(("warning", "root-file", "LICENSE", "A published repository has LICENSE at the root."))
    generated = sorted({match.group(1) + "/" for path in tracked if (match := GENERATED.match(path))})
    found.extend(("error", "generated-committed", folder, "Generated files are never committed.") for folder in generated)
    for singular, plural in (("doc", "docs"), ("example", "examples")):
        if any(path.startswith(singular + "/") for path in tracked):
            found.append(("error", "plural-folder", singular + "/", f"Use {plural}/."))
    apps: dict[str, list[str]] = defaultdict(list)
    for path in tracked:
        parts = path.split("/")
        if len(parts) >= 3 and parts[0] == "apps":
            apps[parts[1]].append(path)
    for app, paths in apps.items():
        direct = any(len(path.split("/")) == 3 for path in paths)
        folders = {path.split("/")[2] for path in paths if len(path.split("/")) > 3}
        if not direct and len(folders) == 1:
            folder = next(iter(folders))
            found.append(("error", "empty-nesting", f"apps/{app}/{folder}/", f"Move its content up into apps/{app}/."))
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", "-Path", type=Path, default=Path.cwd())
    args = parser.parse_args()
    try:
        root = args.path.resolve(strict=True)
        problems = findings(root)
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    if not problems:
        print(f"Layout check passed: {root}")
        return 0
    print("| Severity | Rule | Path | Detail |\n| --- | --- | --- | --- |")
    for severity, rule, path, detail in problems:
        print(f"| {severity} | {rule} | `{path}` | {detail} |")
    errors = sum(severity == "error" for severity, *_ in problems)
    print(f"{errors} error(s), {len(problems) - errors} warning(s).")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
