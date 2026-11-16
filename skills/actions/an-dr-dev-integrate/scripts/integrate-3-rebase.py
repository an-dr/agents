"""Strip tmp files from the branch, then fetch the base and rebase onto it."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path


class Failure(Exception):
    """A step cannot go on."""


# Work files every flow keeps beside the code: tmp-agent-wip.json, the progress
# page, generated reports. Any file or folder whose name starts with tmp- or
# .tmp-, at any depth. They travel on a work branch and never land.
# Subject prefix of temporary commits that never land.
DO_NOT_MERGE = "DO-NOT-MERGE:"
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
    """Refuse to land a branch whose history still carries tmp files."""
    paths = tmp_paths(base)
    if paths:
        raise Failure(f"The branch still carries tmp files ({', '.join(paths)}); run integrate-3-rebase.py first.")


def set_environment_value(name: str, value: str | None) -> None:
    """Set an environment variable for the Git child processes, or unset it."""
    if value:
        os.environ[name] = value
    else:
        os.environ.pop(name, None)


def remove_quietly(path: Path) -> None:
    """Delete a file, ignoring a missing path or a folder that is not empty."""
    try:
        path.unlink()
    except OSError:
        pass


def strip_tmp_history(base: str) -> None:
    """Rewrite every commit after the base without tmp files, drop the commits that held nothing else,
    and delete the stripped files from disk. Records the base in the branch config first, since the
    state file that named it is one of the files removed."""
    branch = current_branch()
    git("config", f"branch.{branch}.an-dr-base", base)
    stripped = tmp_paths(base)
    if not stripped:
        print("No tmp files on the branch; nothing to strip.")
        return
    merge_base = git("merge-base", base, "HEAD").strip()
    if git("rev-list", "--min-parents=2", f"{merge_base}..HEAD").strip():
        raise Failure("Stripping tmp files needs linear history; rebase away merge commits first.")
    commits = git("rev-list", "--reverse", f"{merge_base}..HEAD").splitlines()
    old_tip = git("rev-parse", "HEAD").strip()
    new_parent = merge_base
    rewritten = 0
    pruned = 0
    index = os.path.join(tempfile.gettempdir(), f"agents-strip-tmp-{uuid.uuid4()}.index")
    descriptor, message_path = tempfile.mkstemp()
    os.close(descriptor)
    keys = ("GIT_INDEX_FILE", "GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL", "GIT_AUTHOR_DATE",
            "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL", "GIT_COMMITTER_DATE")
    saved = {key: os.environ.get(key) for key in keys}
    try:
        set_environment_value("GIT_INDEX_FILE", index)
        for commit in commits:
            git("read-tree", commit)
            git("rm", "-r", "--cached", "--quiet", "--ignore-unmatch", "--", *TMP_PATHSPEC)
            tree = git("write-tree").strip()
            if tree == git("rev-parse", f"{new_parent}^{{tree}}").strip():
                pruned += 1
                continue
            if git("show", "-s", "--format=%s", commit).startswith(DO_NOT_MERGE):
                raise Failure(
                    f"Commit {commit[:9]} is marked {DO_NOT_MERGE} but changes files beyond tmp ones; "
                    "drop or rewrite it before landing."
                )
            message = "\n".join(git("show", "-s", "--format=%B", commit).splitlines())
            Path(message_path).write_text(f"{message}\n", encoding="utf-8", newline="")
            meta = "".join(git("show", "-s", "--format=%an%x00%ae%x00%aI%x00%cn%x00%ce%x00%cI", commit).splitlines())
            for key, value in zip(keys[1:], meta.split("\0")):
                set_environment_value(key, value)
            new_parent = git("commit-tree", tree, "-p", new_parent, "-F", message_path).strip()
            rewritten += 1
    finally:
        for key in keys:
            set_environment_value(key, saved[key])
        remove_quietly(Path(index))
        remove_quietly(Path(message_path))
    git("update-ref", f"refs/heads/{branch}", new_parent, old_tip)
    # update-ref leaves the index at the old tip; the clean-tree precondition
    # means there is nothing staged to keep.
    git("reset", "--quiet", "--mixed", "HEAD")
    root = Path(git("rev-parse", "--show-toplevel").strip())
    for path in stripped:
        remove_quietly(root / path)
    remove_quietly(root / "tmp-agent-progress.html")
    assert_no_tmp(base)
    print(f"Stripped {len(stripped)} tmp path(s): {rewritten} commit(s) rewritten, {pruned} tmp-only commit(s) dropped.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-branch", "-BaseBranch", default="", help="base branch (default: the branch the work started from)")
    parser.add_argument("--wip-data-skill", "-WipDataSkill", required=True, help="folder of the an-dr-ai-use-wip-data skill")
    args = parser.parse_args()
    try:
        base = resolve_base(args.base_branch, args.wip_data_skill)
        assert_feature_branch(base)
        assert_clean_tree()
        strip_tmp_history(base)

        print(f"Fetching 'origin/{base}'...")
        print(git("fetch", "origin", base), end="")
        print(f"Rebasing onto 'origin/{base}'...")
        print(git("rebase", f"origin/{base}"), end="")
        print()
        print(git("log", "--oneline", f"{base}..HEAD"), end="")
    except (OSError, ValueError, Failure) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
