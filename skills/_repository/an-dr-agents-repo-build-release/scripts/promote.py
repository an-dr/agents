"""Promote a tested dev commit to main by fast-forward."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def git(root: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["git", "-C", str(root), *args], capture_output=True, encoding="utf-8", errors="replace", check=False
    )
    if check and result.returncode:
        raise RuntimeError(result.stderr.strip() or f"git {' '.join(args)} failed")
    return result


def promote(args: argparse.Namespace) -> None:
    root = args.root
    if git(root, "branch", "--show-current").stdout.strip() != args.dev_branch:
        raise RuntimeError(f"Check out '{args.dev_branch}' first; only its tip can be promoted.")
    if git(root, "status", "--porcelain").stdout.strip():
        raise RuntimeError("The working tree is not clean; commit or stash before promoting.")
    if git(root, "merge-base", "--is-ancestor", args.main_branch, "HEAD", check=False).returncode:
        raise RuntimeError(f"'{args.main_branch}' is not an ancestor of '{args.dev_branch}'; no fast-forward is possible.")
    tip = git(root, "rev-parse", "HEAD").stdout.strip()
    if tip == git(root, "rev-parse", args.main_branch).stdout.strip():
        print(f"'{args.main_branch}' already points at {tip[:8]}; nothing to promote.")
        return
    command = args.test_command or [sys.executable, "tests/run-all.py", "--all"]
    print(f"Testing {tip[:8]}: {' '.join(command)}")
    tests = subprocess.run(command, cwd=root, check=False)
    if tests.returncode:
        raise RuntimeError(f"The tests failed on {tip[:8]}; '{args.main_branch}' did not move.")
    if git(root, "status", "--porcelain").stdout.strip():
        raise RuntimeError("The tests changed the working tree; the tested commit is not what would be promoted.")
    git(root, "branch", "-f", args.main_branch, tip)
    print(f"'{args.main_branch}' moved to {tip[:8]}.")
    if not args.no_push:
        git(root, "push", args.remote, args.main_branch, args.dev_branch)
        print(f"Pushed '{args.main_branch}' and '{args.dev_branch}' to {args.remote}.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="The repository to promote in.")
    parser.add_argument("--main-branch", default="main", help="The release branch.")
    parser.add_argument("--dev-branch", default="dev", help="The integration branch.")
    parser.add_argument("--remote", default="origin", help="The remote to push to.")
    parser.add_argument("--no-push", action="store_true", help="Move the local main only.")
    parser.add_argument("--test-command", nargs="+", help="Replace the default full test run.")
    args = parser.parse_args()
    try:
        promote(args)
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
