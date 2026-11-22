"""Create the folder for an artifact of a kind, or a named one-off artifact without a kind, and print its path."""

from __future__ import annotations

import argparse
import datetime as dt
import re
import subprocess
import sys
from pathlib import Path


STAMP = re.compile(r"^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}(?:-\d+)?$")
EXTENSION = re.compile(r"^[a-z0-9]+(?:\.[a-z0-9]+)*$")
NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
OTHER = "other"


def artifact_path(kind: str | None, extension: str, stamp: str | None, repository_root: Path | None, name: str | None = None, internal: bool = False) -> Path:
    if internal and not kind:
        raise ValueError("--internal needs --kind; a one-off artifact is never internal.")
    kind = kind or OTHER
    if not NAME.fullmatch(kind):
        raise ValueError(f"Artifact kind must be lowercase hyphenated words, such as code-review, not '{kind}'.")
    if kind == OTHER and not (name and NAME.fullmatch(name)):
        raise ValueError(f"An artifact without a kind needs --name in lowercase hyphenated words, such as plugin-comparison, not '{name}'.")
    if kind != OTHER and name:
        raise ValueError(f"--name applies only to an artifact without a kind; a kind names its own files.")
    stem = f"{{stamp}}-{name}" if kind == OTHER else f"{kind}-{{stamp}}"
    extension = extension.lstrip(".")
    if not EXTENSION.fullmatch(extension):
        raise ValueError(f"Artifact extension must be lowercase, such as html or questions.json, not '{extension}'.")
    if repository_root is None:
        result = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False)
        if result.returncode or not result.stdout.strip():
            raise ValueError("Run this script inside the repository the artifact belongs to, or pass --repository-root.")
        repository_root = Path(result.stdout.strip())
    temporary_root = repository_root.resolve() / ".tmp-ai-gen"
    directory = temporary_root / ".internal" / kind if internal else temporary_root / kind
    directory.mkdir(parents=True, exist_ok=True)
    ignore = temporary_root / ".gitignore"
    if not ignore.exists():
        ignore.write_text("# Generated AI artifacts; nothing here is committed\n*\n", encoding="utf-8")
    if not stamp:
        minute = dt.datetime.now().strftime("%Y-%m-%d_%H-%M")
        stamp = minute
        suffix = 1
        while any(directory.glob(stem.format(stamp=stamp) + ".*")):
            suffix += 1
            stamp = f"{minute}-{suffix}"
    if not STAMP.fullmatch(stamp):
        raise ValueError(f"Artifact stamp must look like 2026-11-01_14-32, not '{stamp}'.")
    return directory / f"{stem.format(stamp=stamp)}.{extension}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("extension")
    parser.add_argument("--kind", "-Kind", help="The artifact kind the calling skill declares; omit for a one-off artifact.")
    parser.add_argument("--stamp", "-Stamp")
    parser.add_argument("--repository-root", "-RepositoryRoot", type=Path)
    parser.add_argument("--internal", "-Internal", action="store_true", help="Place the kind under .tmp-ai-gen/.internal/: state a skill keeps for itself, not output for the user.")
    parser.add_argument("--name", "-Name", help="File name of a one-off artifact without a kind, in lowercase hyphenated words.")
    args = parser.parse_args()
    try:
        print(artifact_path(args.kind, args.extension, args.stamp, args.repository_root, args.name, args.internal))
    except ValueError as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    sys.exit(main())
