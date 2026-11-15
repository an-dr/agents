"""Squash every commit after a given commit into one, with a checked message."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


class Failure(Exception):
    """A step cannot go on."""


# The helpers below are a copy of this skill's former Integrate.Common.psm1. This skill owns the
# copy, and each step script carries the ones it needs so that it runs standalone.


def git(*arguments: str) -> str:
    """Run Git and raise with its captured output on any nonzero exit."""
    result = subprocess.run(["git", *arguments], capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    sys.stderr.write(result.stderr)
    if result.returncode:
        raise Failure(f"git {' '.join(arguments)} failed with exit code {result.returncode}. See Git output above.")
    return result.stdout


def git_status(*arguments: str) -> int:
    """Run Git for its exit code only."""
    return subprocess.run(["git", *arguments], capture_output=True, text=True, encoding="utf-8", errors="replace", check=False).returncode


def git_tolerant(*arguments: str) -> tuple[int, str]:
    """Run Git where a nonzero exit is an answer rather than an error."""
    result = subprocess.run(["git", *arguments], capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    return result.returncode, result.stdout


def local_branch_exists(branch: str) -> bool:
    """Report whether a local branch exists."""
    return git_status("show-ref", "--verify", "--quiet", f"refs/heads/{branch}") == 0


def current_branch() -> str:
    """Return the checked-out branch and reject a detached HEAD."""
    branch = git("branch", "--show-current").strip()
    if not branch:
        raise Failure("Integration operations require a checked-out branch, not detached HEAD.")
    return branch


def workflow_base_branch(wip_data_skill: str) -> str:
    """workflow.baseBranch from tmp-agent-wip.json, read through an-dr-ai-use-wip-data; empty when absent."""
    script = Path(wip_data_skill) / "scripts" / "wip.py"
    if not script.is_file():
        raise Failure(f"--wip-data-skill must be an-dr-ai-use-wip-data's folder; '{script}' does not exist.")
    result = subprocess.run(
        [sys.executable, str(script), "get", "--section", "workflow", "--field", "baseBranch", "--reader", "an-dr-dev-integrate"],
        capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    text = (result.stdout if result.returncode == 0 else "").strip()
    if not text or text == "null":
        return ""
    value = json.loads(text)
    return "" if value is None else str(value)


def resolve_base(requested: str, wip_data_skill: str) -> str:
    """Resolve an explicit base, the base the work started from, or the repository default branch."""
    if requested:
        if not local_branch_exists(requested):
            raise Failure(f"Local base branch '{requested}' does not exist.")
        return requested

    # The branch the work started from: recorded in the branch's config once
    # its tmp files are stripped, and in tmp-agent-wip.json until then.
    current = git_tolerant("branch", "--show-current")[1].strip()
    if current:
        recorded = git_tolerant("config", "--get", f"branch.{current}.an-dr-base")[1].strip()
        if recorded and local_branch_exists(recorded):
            return recorded
        from_state = workflow_base_branch(wip_data_skill)
        if from_state and local_branch_exists(from_state):
            return from_state

    code, remote_head = git_tolerant("symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
    if code == 0 and remote_head.strip():
        candidate = re.sub(r"^origin/", "", remote_head.strip().splitlines()[0])
        if local_branch_exists(candidate):
            return candidate
    for candidate in ("main", "master", "trunk"):
        if local_branch_exists(candidate):
            return candidate
    raise Failure("Cannot detect the base branch. Pass --base-branch explicitly.")


def assert_feature_branch(base: str) -> str:
    """Verify that HEAD is a feature branch and return its name."""
    branch = current_branch()
    if branch == base:
        raise Failure(f"Already on base branch '{base}'. Switch to the feature branch first.")
    return branch


def assert_clean_tree() -> None:
    """Reject tracked, staged, and untracked working-tree changes."""
    if git("status", "--porcelain").strip():
        raise Failure("Working tree is not clean. Commit or stash changes first.")


def assert_ancestor(ancestor: str, descendant: str) -> None:
    """Verify that one commit is an ancestor of another."""
    if git_status("merge-base", "--is-ancestor", ancestor, descendant):
        raise Failure(f"'{ancestor}' is not an ancestor of '{descendant}'.")


def check_message(commit_message_skill: str, message: str, label: str) -> int:
    """Run commit-message's public check-message script and return its exit code."""
    folder = Path(commit_message_skill) / "scripts"
    python_checker = folder / "check-message.py"
    powershell_checker = folder / "check-message.ps1"
    if python_checker.is_file():
        command = [sys.executable, str(python_checker), "--message", message, "--label", label, "--quiet"]
    elif powershell_checker.is_file():
        # The convention still ships its checker in PowerShell; run that until it is ported.
        command = ["pwsh", "-NoProfile", "-NonInteractive", "-File", str(powershell_checker), "-Message", message, "-Label", label, "-Quiet"]
    else:
        raise Failure("--commit-message-skill must be the commit-message folder; 'scripts/check-message.py' or 'scripts/check-message.ps1' is missing.")
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    return result.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wip-data-skill", "-WipDataSkill", required=True, help="folder of the an-dr-ai-use-wip-data skill")
    parser.add_argument("--hash", "-Hash", required=True, help="commit before the first commit to squash")
    parser.add_argument("--message", "-Message", required=True, help="subject of the squashed commit")
    parser.add_argument("--commit-message-skill", "-CommitMessageSkill", required=True, help="folder of the an-dr-convention-commit-message skill")
    parser.add_argument("--base-branch", "-BaseBranch", default="", help="base branch (default: the branch the work started from)")
    args = parser.parse_args()
    try:
        base = resolve_base(args.base_branch, args.wip_data_skill)
        assert_feature_branch(base)
        assert_clean_tree()
        git("rev-parse", "--verify", f"{args.hash}^{{commit}}")
        assert_ancestor(args.hash, "HEAD")

        # The squashed commit is delivered history, so it obeys the commit message format.
        if check_message(args.commit_message_skill, args.message, "Squash message check:"):
            raise Failure("The squash message breaks the commit message format; nothing was squashed.")

        print(f"Squashing commits after '{args.hash}' into one commit...")
        git("reset", "--soft", args.hash)
        print(git("commit", "-m", args.message), end="")
        print()
        print(git("log", "--oneline", "-6"), end="")
    except (OSError, ValueError, Failure) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
