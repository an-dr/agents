"""Copy all files of an artifact stamp to the kind's latest paths."""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path


def publish(path: Path) -> list[Path]:
    source = path.resolve(strict=True)
    kind = source.parent.name
    root = source.parent.parent
    if kind == "other":
        raise ValueError("Kind 'other' has no latest copy; report the stamped path itself.")
    match = re.fullmatch(rf"{re.escape(kind)}-(\d{{4}}-\d{{2}}-\d{{2}}_\d{{2}}-\d{{2}}(?:-\d+)?)\..+", source.name)
    if root.name != ".tmp-ai-gen" or match is None:
        raise ValueError(f"Not an artifact from new-artifact-path.py: {path}")
    stem = f"{kind}-{match.group(1)}"
    for previous in root.glob(f"{kind}-latest.*"):
        if previous.is_file():
            previous.unlink()
    copies = []
    for current in source.parent.glob(f"{stem}.*"):
        if current.is_file():
            target = root / f"{kind}-latest{current.name[len(stem):]}"
            shutil.copyfile(current, target)
            copies.append(target)
    return copies


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    args = parser.parse_args()
    try:
        for path in publish(args.path):
            print(path)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    sys.exit(main())
