"""Create an artifact kind directory and print a registered output path."""

from __future__ import annotations

import argparse
import datetime as dt
import re
import subprocess
import sys
from pathlib import Path


STAMP = re.compile(r"^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}(?:-\d+)?$")
EXTENSION = re.compile(r"^[a-z0-9]+(?:\.[a-z0-9]+)*$")


def artifact_path(kind: str, extension: str, stamp: str | None, repository_root: Path | None) -> Path:
    kinds = (Path(__file__).resolve().parent.parent / "assets" / "kinds.txt").read_text(encoding="utf-8").splitlines()
    kinds = [entry.strip() for entry in kinds if entry.strip()]
    if kind not in kinds:
        raise ValueError(f"Artifact kind '{kind}' is not registered in assets/kinds.txt ({', '.join(kinds)}).")
    extension = extension.lstrip(".")
    if not EXTENSION.fullmatch(extension):
        raise ValueError(f"Artifact extension must be lowercase, such as html or questions.json, not '{extension}'.")
    if repository_root is None:
        result = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False)
        if result.returncode or not result.stdout.strip():
            raise ValueError("Run this script inside the repository the artifact belongs to, or pass --repository-root.")
        repository_root = Path(result.stdout.strip())
    temporary_root = repository_root.resolve() / ".tmp-ai-gen"
    directory = temporary_root / kind
    directory.mkdir(parents=True, exist_ok=True)
    ignore = temporary_root / ".gitignore"
    if not ignore.exists():
        ignore.write_text("# Generated AI artifacts; nothing here is committed\n*\n", encoding="utf-8")
    if not stamp:
        minute = dt.datetime.now().strftime("%Y-%m-%d_%H-%M")
        stamp = minute
        suffix = 1
        while any(directory.glob(f"{kind}-{stamp}.*")):
            suffix += 1
            stamp = f"{minute}-{suffix}"
    if not STAMP.fullmatch(stamp):
        raise ValueError(f"Artifact stamp must look like 2026-11-01_14-32, not '{stamp}'.")
    return directory / f"{kind}-{stamp}.{extension}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind")
    parser.add_argument("extension")
    parser.add_argument("--stamp", "-Stamp")
    parser.add_argument("--repository-root", "-RepositoryRoot", type=Path)
    args = parser.parse_args()
    try:
        print(artifact_path(args.kind, args.extension, args.stamp, args.repository_root))
    except ValueError as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    sys.exit(main())
