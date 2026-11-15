"""Report whether main has fallen behind dev for too long."""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path


def git(root: Path, *args: str) -> str | None:
    result = subprocess.run(
        ["git", "-C", str(root), *args], capture_output=True, encoding="utf-8", errors="replace", check=False
    )
    return result.stdout.strip() if result.returncode == 0 else None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="The repository to check.")
    parser.add_argument("--main-branch", default="main", help="The release branch.")
    parser.add_argument("--dev-branch", default="dev", help="The integration branch.")
    parser.add_argument("--max-days", type=float, default=14, help="Days main may lag behind dev.")
    parser.add_argument("--max-commits", type=int, default=20, help="Unpromoted dev commits allowed.")
    args = parser.parse_args()

    stamp = git(args.root, "log", "-1", "--format=%ct", args.main_branch)
    ahead = git(args.root, "rev-list", "--count", f"{args.main_branch}..{args.dev_branch}")
    if stamp is None or ahead is None:
        print(f"Cannot compare '{args.main_branch}' with '{args.dev_branch}': a branch is missing.", file=sys.stderr)
        return 2
    days = (time.time() - int(stamp)) / 86400
    ahead_count = int(ahead)
    stale = ahead_count > 0 and (days > args.max_days or ahead_count > args.max_commits)

    print("| Measure | Value | Limit |\n| --- | --- | --- |")
    print(f"| days since `{args.main_branch}` moved | {days:.1f} | {args.max_days:g} |")
    print(f"| `{args.dev_branch}` commits not on `{args.main_branch}` | {ahead_count} | {args.max_commits} |")
    if stale:
        print(f"`{args.main_branch}` is stale: promote a tested `{args.dev_branch}` commit with promote.py.")
    elif ahead_count:
        print(f"`{args.main_branch}` is behind `{args.dev_branch}` but within the limits.")
    else:
        print(f"`{args.main_branch}` is current.")
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
