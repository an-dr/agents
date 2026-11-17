"""Interactive integration. Always asks which mode to use.

Regroup needs a plan, so it is run through the step scripts instead.
"""

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


def workflow_base_branch(wip_data_skill: str) -> str:
    """workflow.baseBranch from tmp-agent-wip.json, read through an-dr-ai-use-wip-data; empty when absent."""
    script = Path(wip_data_skill) / "scripts" / "wip.py"
    if not script.is_file():
        raise Failure(f"--wip-data-skill must be an-dr-ai-use-wip-data's folder; '{script}' does not exist.")
    result = subprocess.run(
        [sys.executable, str(script), "get", "--section", "workflow", "--field", "baseBranch", "--reader", "an-dr-dev-integrate"],
        capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    text = (result.stdout if result.returncode == 0 else "").strip()
    value = json.loads(text) if text else None
    return "" if value is None else str(value)


def resolve_base(requested: str, wip_data_skill: str) -> str:
    """Resolve an explicit base, the base the work started from, or the repository default branch."""
    if requested:
        if not local_branch_exists(requested):
            raise Failure(f"Local base branch '{requested}' does not exist.")
        return requested

    # The branch the work started from: the handed-over state names it, and
    # step 3 copies it to the branch config before it drops that state.
    from_state = workflow_base_branch(wip_data_skill)
    if from_state and local_branch_exists(from_state):
        return from_state
    current = git_tolerant("branch", "--show-current")[1].strip()
    if current:
        recorded = git_tolerant("config", "--get", f"branch.{current}.an-dr-base")[1].strip()
        if recorded and local_branch_exists(recorded):
            return recorded

    code, remote_head = git_tolerant("symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD")
    if code == 0 and remote_head.strip():
        candidate = re.sub(r"^origin/", "", remote_head.strip().splitlines()[0])
        if local_branch_exists(candidate):
            return candidate
    for candidate in ("main", "master", "trunk"):
        if local_branch_exists(candidate):
            return candidate
    raise Failure("Cannot detect the base branch. Pass --base-branch explicitly.")


def run_step(name: str, arguments: list[str]) -> int:
    """Run a step script next to this one, in a fresh Python process, and return its exit code."""
    script = Path(__file__).resolve().parent / name
    return subprocess.run([sys.executable, str(script), *arguments], check=False).returncode


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--commit-message-skill", "-CommitMessageSkill", required=True, help="folder of the an-dr-convention-commit-message skill")
    parser.add_argument("--base-branch", "-BaseBranch", default="", help="base branch (default: the branch the work started from)")
    parser.add_argument("--wip-data-skill", "-WipDataSkill", required=True, help="folder of the an-dr-ai-use-wip-data skill")
    args = parser.parse_args()
    try:
        base = resolve_base(args.base_branch, args.wip_data_skill)
        code = run_step("integrate-1-check.py", ["--base-branch", base, "--wip-data-skill", args.wip_data_skill])
        if code:
            return code
        code = run_step("integrate-3-rebase.py", ["--base-branch", base, "--wip-data-skill", args.wip_data_skill])
        if code:
            return code
        print()
        confirm = input("WIP commits at the tip are already squashed (or none exist)? [y/N]: ")
        if confirm not in ("y", "Y"):
            raise Failure("Integration cancelled after the rebase; the base is untouched.")
        code = run_step("integrate-1-check.py", ["--base-branch", base, "--wip-data-skill", args.wip_data_skill])
        if code:
            return code

        print()
        print("Integration mode:")
        print(f"  1  Commits  keep every commit, fast-forward '{base}' (no merge commit)")
        print(f"  2  Squash   collapse the branch into one commit, fast-forward '{base}'")
        print("  3  Request  collapse into one commit, push the branch, open a request")
        print("  4  RebaseMerge  push the branch with its commits, open a request;")
        print("                 integrate-5-rebase-merge.py lands it once CI passes")
        modes = {"1": "Commits", "2": "Squash", "3": "Request", "4": "RebaseMerge"}
        mode = ""
        while not mode:
            mode = modes.get(input("Choose 1, 2, 3, or 4: ").strip(), "")
            if not mode:
                print("Answer 1, 2, 3, or 4.")

        message = ""
        if mode in ("Squash", "Request"):
            print("The commit message must match the commit message format; the squash is rejected otherwise.")
            message = input("Single commit subject: ")
            if not message.strip():
                raise Failure("A non-empty commit message is required.")
    except (OSError, EOFError, ValueError, Failure) as error:
        print(error, file=sys.stderr)
        return 1
    return run_step("integrate-4-finish.py", [
        "--mode", mode, "--message", message, "--base-branch", base,
        "--commit-message-skill", args.commit_message_skill, "--wip-data-skill", args.wip_data_skill])


if __name__ == "__main__":
    sys.exit(main())
