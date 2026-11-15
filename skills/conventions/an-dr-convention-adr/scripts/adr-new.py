"""Create the next numbered architecture decision record."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


def create(title: str) -> Path:
    if not title.strip():
        raise ValueError("ADR title cannot be blank.")
    result = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False)
    if result.returncode or not result.stdout.strip():
        raise ValueError("Run the ADR script inside a Git repository.")
    directory = Path(result.stdout.strip()) / "docs" / "adr"
    directory.mkdir(parents=True, exist_ok=True)
    slug = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    if not slug:
        raise ValueError("ADR title must contain at least one ASCII letter or number for its filename.")
    numbers = [int(match.group(1)) for path in directory.glob("ADR-*.md") if (match := re.match(r"ADR-(\d+)", path.name))]
    number = max(numbers, default=0) + 1
    for _ in range(100):
        path = directory / f"ADR-{number:03d}-{slug}.md"
        content = f"# ADR-{number:03d}: {title}\n\n## Problem\n\n## Decision\n\n## Rationale\n\n## Rejected alternatives\n"
        try:
            with path.open("x", encoding="utf-8") as stream:
                stream.write(content)
            return path
        except FileExistsError:
            number += 1
    raise ValueError("Unable to reserve an ADR number after 100 attempts.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--title", "-Title", required=True)
    args = parser.parse_args()
    try:
        print(f"Created {create(args.title)}")
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
