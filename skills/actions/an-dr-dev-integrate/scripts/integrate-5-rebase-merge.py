"""Land a RebaseMerge pull request with the platform's rebase and merge.

--tested-commit names the commit whose CI passed. The local branch may differ
from it only in history (fixups folded, commits regrouped), never in tree: the
script refuses otherwise. When the local branch is not yet on the remote, it
force-pushes it and cancels the CI runs that push starts, because that tree has
already passed.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path


class Failure(Exception):
    """A step cannot go on."""


# Work files every flow keeps beside the code: tmp-agent-wip.json, the progress
# page, generated reports. Any file or folder whose name starts with tmp- or
# .tmp-, at any depth. They travel on a work branch and never land.
TMP_PATHSPEC = (":(glob)**/tmp-*", ":(glob)**/tmp-*/**", ":(glob)**/.tmp-*", ":(glob)**/.tmp-*/**")


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


def git_output(*arguments: str) -> str:
    """Run Git and keep what it printed, even when it exits nonzero."""
    result = subprocess.run(["git", *arguments], capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    sys.stderr.write(result.stderr)
    return result.stdout


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


def tmp_paths(base: str) -> list[str]:
    """The tmp paths that any commit after the base, or HEAD, still carries."""
    merge_base = git("merge-base", base, "HEAD").strip()
    logged = git("log", "--format=", "--name-only", f"{merge_base}..HEAD", "--", *TMP_PATHSPEC)
    # Kept as it was: Git refuses the glob pathspec magic on ls-tree, so this listing answers with
    # nothing and the step goes on; the log above already names every tmp path the branch carries.
    listed = git_output("ls-tree", "-r", "--name-only", "HEAD", "--", *TMP_PATHSPEC)
    return sorted({path for path in (*logged.splitlines(), *listed.splitlines()) if path.strip()})


def assert_no_tmp(base: str) -> None:
    """Refuse to land a branch whose history still carries tmp files or DO-NOT-MERGE commits."""
    paths = tmp_paths(base)
    if paths:
        raise Failure(f"The branch still carries tmp files ({', '.join(paths)}); run integrate-3-rebase.py first.")
    merge_base = git("merge-base", base, "HEAD").strip()
    marked = [s for s in git("log", "--format=%s", f"{merge_base}..HEAD").splitlines() if s.startswith("DO-NOT-MERGE:")]
    if marked:
        raise Failure(f"The branch still carries DO-NOT-MERGE commits ({'; '.join(marked)}); remove them first.")


def gh_available() -> bool:
    """Report whether the GitHub CLI is available for merging the request."""
    return shutil.which("gh") is not None


def tree_of(commit: str) -> str:
    """The tree a commit points at."""
    return git("rev-parse", f"{commit}^{{tree}}").strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--wip-data-skill", "-WipDataSkill", required=True, help="folder of the an-dr-ai-use-wip-data skill")
    parser.add_argument("--tested-commit", "-TestedCommit", required=True, help="commit whose CI passed")
    parser.add_argument("--base-branch", "-BaseBranch", default="", help="base branch (default: the branch the work started from)")
    args = parser.parse_args()
    try:
        if not gh_available():
            raise Failure("RebaseMerge needs the GitHub CLI (gh) to merge the request.")
        base = resolve_base(args.base_branch, args.wip_data_skill)
        branch = assert_feature_branch(base)
        assert_clean_tree()
        assert_no_tmp(base)

        tested = git("rev-parse", args.tested_commit).strip()
        head = git("rev-parse", "HEAD").strip()
        if tree_of(tested) != tree_of(head):
            raise Failure(f"HEAD's tree differs from {args.tested_commit}'s, so its CI result does not cover HEAD. Push it and let CI run.")

        listed = subprocess.run(["gh", "run", "list", "--commit", tested, "--json", "conclusion,name"],
                                capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
        runs = json.loads(listed.stdout) if listed.stdout.strip() else []
        if listed.returncode != 0 or not runs:
            raise Failure(f"No CI runs found for {args.tested_commit}.")
        unpassed = [run for run in runs if run.get("conclusion") not in ("success", "skipped")]
        if unpassed:
            details = ", ".join(f"{run.get('name') or ''}={run.get('conclusion') or ''}" for run in unpassed)
            raise Failure(f"CI has not passed for {args.tested_commit}: {details}")

        git("fetch", "origin", branch)
        remote = git("rev-parse", f"origin/{branch}").strip()
        if remote != head:
            print(f"Pushing '{branch}'; its tree passed CI as {args.tested_commit}.")
            print(git("push", "--force-with-lease", "origin", branch), end="")
            # Runs register a few seconds after the push, so look for a while.
            cancelled: dict[int, bool] = {}
            for _ in range(6):
                time.sleep(5)
                started = subprocess.run(["gh", "run", "list", "--commit", head, "--json", "databaseId,status"],
                                         capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
                for run in json.loads(started.stdout) if started.stdout.strip() else []:
                    identity = run.get("databaseId")
                    if run.get("status") != "completed" and not cancelled.get(identity):
                        subprocess.run(["gh", "run", "cancel", str(identity)], capture_output=True, text=True, check=False)
                        cancelled[identity] = True
                        print(f"Cancelled CI run {identity}.")

        print(f"Rebase-merging '{branch}' into '{base}'...")
        if subprocess.run(["gh", "pr", "merge", branch, "--rebase", "--delete-branch"], check=False).returncode:
            raise Failure("gh pr merge failed. See the output above; nothing was merged.")
        if current_branch() != base:
            git("checkout", base)
        print(git("pull", "--ff-only", "origin", base), end="")
        if local_branch_exists(branch):
            print(git("branch", "-D", branch), end="")
        print()
        print(git("log", "--oneline", "-5"), end="")
        print(f"Integration complete. '{branch}' was rebase-merged and removed.")
    except (OSError, ValueError, Failure) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
