"""Rebuild the feature branch as the logical commits a JSON plan names, for the Regroup mode.

The plan is a JSON file:

    { "commits": [ { "message": "<commit message>", "paths": ["dir", "file"] } ] }

Commits are made in plan order from the branch's final tree; each stages its
paths with `git add -A`. Every message is checked before anything is touched,
the branch is kept under a backup ref, and any failure restores it. The result
must hold exactly the original tree.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path


TMP_PATHSPEC = (":(glob)**/tmp-*", ":(glob)**/tmp-*/**", ":(glob)**/.tmp-*", ":(glob)**/.tmp-*/**")


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


# Subject prefix of commits that never land: the handover keeps the workflow
# state in one at the tip, and step 3 drops them before anything lands.
DO_NOT_MERGE = "DO-NOT-MERGE:"
REVERT_SUBJECT = re.compile(r'^(Revert "|revert(\([^)]*\))?!?: )')
REVERT_BODY = re.compile(r"^This reverts commit [0-9a-f]{7,}", re.M)
EXCLUDE_TMP = tuple(spec.replace(":(glob)", ":(exclude,glob)") for spec in TMP_PATHSPEC)


def land_tip(base: str) -> str:
    """The commit the branch lands at: HEAD without its trailing DO-NOT-MERGE commits.

    Refuses a branch that carries a revert, a DO-NOT-MERGE commit below work
    that lands, one that changes anything but tmp files, or a tmp file in a
    commit that lands: the handover leaves none of these, so each means the
    branch was not handed over cleanly.
    """
    merge_base = git("merge-base", base, "HEAD").strip()
    commits = git("rev-list", "--reverse", f"{merge_base}..HEAD").split()
    for commit in commits:
        subject = git("show", "-s", "--format=%s", commit).strip()
        if REVERT_SUBJECT.match(subject) or REVERT_BODY.search(git("show", "-s", "--format=%b", commit)):
            raise Failure(f"Commit {commit[:9]} ('{subject}') is a revert; a branch with reverts does not land. "
                          "Drop the revert and the commit it undoes, then integrate again.")
    marked = [git("show", "-s", "--format=%s", commit).startswith(DO_NOT_MERGE) for commit in commits]
    keep = len(commits)
    while keep and marked[keep - 1]:
        keep -= 1
    if any(marked[:keep]):
        raise Failure(f"A {DO_NOT_MERGE} commit sits below work that lands; move it to the tip or drop it.")
    for commit in commits[keep:]:
        if git("diff", "--name-only", f"{commit}^", commit, "--", ".", *EXCLUDE_TMP).strip():
            raise Failure(f"Commit {commit[:9]} is marked {DO_NOT_MERGE} but changes files beyond tmp ones; "
                          "move that work into a commit that lands.")
    if not keep:
        raise Failure("The branch holds nothing but DO-NOT-MERGE commits; there is nothing to land.")
    tip = commits[keep - 1]
    carried = sorted({p for p in git("log", "--format=", "--name-only", f"{merge_base}..{tip}", "--", *TMP_PATHSPEC).splitlines() if p})
    if carried:
        raise Failure(f"Commits that land carry tmp files ({', '.join(carried)}); a handover strips them with "
                      "an-dr-git-modify-history's strip-tmp-files.py.")
    return tip


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


def assert_feature_branch(base: str) -> str:
    """Verify that HEAD is a feature branch and return its name."""
    branch = current_branch()
    if branch == base:
        raise Failure(f"Already on base branch '{base}'. Switch to the feature branch first.")
    return branch


def assert_clean_tree() -> None:
    """Reject tracked, staged, and untracked working-tree changes; untracked tmp files are work files."""
    if git("status", "--porcelain", "--", ".", *EXCLUDE_TMP).strip():
        raise Failure("Working tree is not clean. Commit or stash changes first.")


def squash_point(base: str) -> str:
    """Return the commit the branch's own work starts from."""
    point = git("merge-base", f"origin/{base}", "HEAD").strip()
    if not point:
        raise Failure(f"Cannot locate the merge base of 'origin/{base}' and HEAD.")
    return point


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
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--plan", "-Plan", required=True, help="JSON plan of the commits to build")
    parser.add_argument("--commit-message-skill", "-CommitMessageSkill", required=True, help="folder of the an-dr-convention-commit-message skill")
    parser.add_argument("--base-branch", "-BaseBranch", default="", help="base branch (default: the branch the work started from)")
    parser.add_argument("--wip-data-skill", "-WipDataSkill", required=True, help="folder of the an-dr-ai-use-wip-data skill")
    args = parser.parse_args()
    try:
        base = resolve_base(args.base_branch, args.wip_data_skill)
        branch = assert_feature_branch(base)
        assert_clean_tree()
        if land_tip(base) != git("rev-parse", "HEAD").strip():
            raise Failure(f"The branch ends in {DO_NOT_MERGE} commits; run integrate-3-rebase.py to drop them first.")

        plan = json.loads(Path(args.plan).read_text(encoding="utf-8-sig"))
        commits = plan.get("commits") or []
        if not commits:
            raise Failure(f"The plan '{args.plan}' lists no commits.")

        # A message rejected halfway would leave its group staged for the next
        # commit, so every message passes before the history is touched.
        rejected = 0
        for number, entry in enumerate(commits, start=1):
            message = entry.get("message") if isinstance(entry, dict) else None
            if not message or not entry.get("paths"):
                raise Failure(f"Plan commit {number} needs a message and at least one path.")
            rejected += bool(check_message(args.commit_message_skill, entry["message"], f"Plan commit {number} message check:"))
        if rejected:
            raise Failure("A plan message breaks the commit message format; nothing was regrouped.")

        point = squash_point(base)
        tree = git("rev-parse", "HEAD^{tree}").strip()
        backup = f"backup/{branch}-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
        git("branch", backup, "HEAD")
        print(f"Kept the branch as '{backup}'.")

        try:
            git("reset", "--mixed", "--quiet", point)
            for number, entry in enumerate(commits, start=1):
                git("add", "-A", "--", *entry["paths"])
                if git_status("diff", "--cached", "--quiet") == 0:
                    raise Failure(f"Plan commit {number} stages nothing; its paths hold no change, or an earlier commit took them.")
                git("commit", "--quiet", "-m", entry["message"])
            left = git("status", "--porcelain")
            if left.strip():
                uncovered = "\n".join(left.splitlines())
                raise Failure(f"No plan commit covers:\n{uncovered}")
            result = git("rev-parse", "HEAD^{tree}").strip()
            if result != tree:
                raise Failure("The regrouped tree differs from the original.")
        except Exception as error:
            # Restored exactly, so the backup holds nothing the branch does not.
            git_status("reset", "--hard", "--quiet", backup)
            git_status("branch", "-D", "--quiet", backup)
            raise Failure(f"Regrouping failed and the branch was restored as it was: {error}") from error

        print(f"Rebuilt '{branch}' as {len(commits)} commits with its tree unchanged:")
        print(git("log", "--oneline", f"{point}..HEAD"), end="")
    except (OSError, ValueError, Failure) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
