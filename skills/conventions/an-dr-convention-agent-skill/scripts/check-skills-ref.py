"""Validate every skill with skills-ref, the reference validator of the Agent Skills format.

When skills-ref is not installed the script says how to install it and exits 0,
because installing software is the user's decision; it exits 1 instead when
--require is given or the CI environment variable is set. Prints a Markdown
table of problems and exits 1 when any skill fails.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path


INSTALL = 'pipx install "git+https://github.com/agentskills/agentskills#subdirectory=skills-ref"'


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", "-Root", type=Path, default=Path(__file__).resolve().parents[4])
    parser.add_argument("--require", "-Require", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()

    command = shutil.which("skills-ref")
    if not command:
        print("skills-ref is not installed, so the skills were not validated against the Agent Skills format.\n")
        print("Install it, once per machine:\n")
        print(f"```sh\n{INSTALL}\n```\n")
        print("Without pipx, create a virtual environment and run `pip install` with the same git URL.")
        return 1 if args.require or os.environ.get("CI") else 0

    problems: list[tuple[str, str]] = []
    checked = 0
    for file in sorted((root / "skills").glob("*/*/SKILL.md")):
        checked += 1
        result = subprocess.run([command, "validate", str(file.parent)], capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
        if result.returncode != 0:
            where = f"skills/{file.parent.parent.name}/{file.parent.name}"
            detail = " ".join(line.strip() for line in (result.stdout + result.stderr).splitlines() if line.strip())
            problems.append((where, detail))

    if not problems:
        print(f"skills-ref validated {checked} skills.")
        return 0
    print(f"skills-ref: {len(problems)} of {checked} skill(s) failed.\n")
    print("| Where | Problem |\n| --- | --- |")
    for where, what in problems:
        print(f"| `{where}` | {what.replace('|', '\\|')} |")
    return 1


if __name__ == "__main__":
    sys.exit(main())
