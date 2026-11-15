"""Package the public agents files and write their SHA-256 checksum."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import sys
import tempfile
import zipfile
from pathlib import Path


def package(root: Path, out: Path, tag: str | None) -> Path:
    version_file = root / "VERSION"
    if not version_file.is_file():
        raise ValueError(f"No VERSION file in '{root}'.")
    version = version_file.read_text(encoding="utf-8-sig").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError(f"VERSION '{version}' is not MAJOR.MINOR.PATCH.")
    if tag and tag != f"v{version}":
        raise ValueError(f"Tag '{tag}' does not match VERSION {version}; expected v{version}.")
    if tag and not (root / "docs" / "releases" / f"{version}.md").is_file():
        raise ValueError(f"No release notes at docs/releases/{version}.md.")
    name = f"agents-{version}"
    required = [root / path for path in ("AGENTS.md", "README.md", "VERSION", "LICENSE", "skills/README.md")]
    for path in required:
        if not path.is_file():
            raise ValueError(f"Required package file is missing: {path}")
    skill_files = [path for category in (root / "skills").iterdir() if category.is_dir() and category.name != "_repository" for path in category.rglob("*") if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc"]
    out.mkdir(parents=True, exist_ok=True)
    target = out / f"{name}.zip"
    descriptor, temporary = tempfile.mkstemp(prefix=f".{name}-", suffix=".zip", dir=out)
    os.close(descriptor)
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(required + skill_files):
                archive.write(path, f"{name}/{path.relative_to(root).as_posix()}")
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    (out / "SHA256SUMS").write_text(f"{digest}  {target.name}", encoding="utf-8")
    return target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", "-Root", type=Path, default=Path(__file__).resolve().parents[4])
    parser.add_argument("--out-directory", "-OutDirectory", type=Path, default=Path(tempfile.gettempdir()) / "agents-release")
    parser.add_argument("--tag", "-Tag")
    args = parser.parse_args()
    try:
        print(package(args.root.resolve(), args.out_directory.resolve(), args.tag))
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
