"""Report every commit in a range whose message breaks the commit message format."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import NamedTuple


class GitError(Exception):
    """A Git operation that cannot continue."""


# Copied helpers, owned by this skill: a skill's scripts run standalone and no module
# is shared between skills, so each script carries the part of GitCommitFix.Common it needs.
def invoke_git_command(*arguments: str) -> list[str]:
    """Runs Git and raises with the exit code on any nonzero exit."""
    result = subprocess.run(["git", *arguments], capture_output=True, text=True, check=False)
    if result.returncode != 0:
        if result.stderr:
            sys.stderr.write(result.stderr)
        raise GitError(f"git {' '.join(arguments)} failed with exit code {result.returncode}. See Git output above.")
    return result.stdout.splitlines()


def git_output(*arguments: str) -> str:
    """One Git command's output as a single trimmed string."""
    return "".join(invoke_git_command(*arguments)).strip()


def test_git_local_branch(branch: str) -> bool:
    """Reports whether a local branch exists."""
    result = subprocess.run(
        ["git", "show-ref", "--verify", "--quiet", f"refs/heads/{branch}"], capture_output=True, check=False
    )
    return result.returncode == 0


def get_git_current_branch() -> str:
    """Returns the checked-out branch and rejects detached HEAD."""
    branch = git_output("branch", "--show-current")
    if not branch:
        raise GitError("Integration operations require a checked-out branch, not detached HEAD.")
    return branch


def get_base_branch(requested: str | None = None) -> str:
    """Resolves an explicit base or detects the repository default branch."""
    if requested:
        if not test_git_local_branch(requested):
            raise GitError(f"Local base branch '{requested}' does not exist.")
        return requested
    remote_head = subprocess.run(
        ["git", "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"],
        capture_output=True,
        text=True,
        check=False,
    )
    if remote_head.returncode == 0 and remote_head.stdout.strip():
        candidate = remote_head.stdout.strip().splitlines()[0]
        if candidate.startswith("origin/"):
            candidate = candidate[len("origin/") :]
        if test_git_local_branch(candidate):
            return candidate
    for candidate in ("main", "master", "trunk"):
        if test_git_local_branch(candidate):
            return candidate
    raise GitError("Cannot detect the base branch. Pass --range explicitly.")


def assert_git_clean_working_tree() -> None:
    """Rejects tracked, staged, and untracked working-tree changes."""
    if invoke_git_command("status", "--porcelain"):
        raise GitError("Working tree is not clean. Commit or stash changes first.")


def assert_git_ancestor(ancestor: str, descendant: str) -> None:
    """Verifies that one commit is an ancestor of another."""
    result = subprocess.run(["git", "merge-base", "--is-ancestor", ancestor, descendant], capture_output=True, check=False)
    if result.returncode != 0:
        raise GitError(f"'{ancestor}' is not an ancestor of '{descendant}'.")


class RewriteRange(NamedTuple):
    branch: str
    base_commit: str | None
    commits: list[str]


def resolve_rewrite_range(range_spec: str | None = None, from_root: bool = False, allow_dirty: bool = False) -> RewriteRange:
    """Resolves the linear commit range to rewrite and rejects unsafe states."""
    branch = get_git_current_branch()
    if not allow_dirty:
        assert_git_clean_working_tree()

    if from_root:
        roots = invoke_git_command("rev-list", "--max-parents=0", "HEAD")
        if len(roots) != 1:
            raise GitError(f"Branch '{branch}' has {len(roots)} root commits; pass --range instead.")
        base = None
        commits = invoke_git_command("rev-list", "--reverse", "HEAD")
        merge_spec = ("rev-list", "--min-parents=2", "HEAD")
    else:
        if range_spec:
            base = git_output("rev-parse", f"{range_spec}^{{commit}}")
        else:
            default = get_base_branch()
            if branch == default:
                raise GitError(f"On default branch '{default}'. Pass --range <rev> or --from-root deliberately.")
            base = git_output("merge-base", default, "HEAD")
        assert_git_ancestor(base, "HEAD")
        commits = invoke_git_command("rev-list", "--reverse", f"{base}..HEAD")
        merge_spec = ("rev-list", "--min-parents=2", f"{base}..HEAD")

    if not commits:
        raise GitError("The selected range holds no commits.")
    if invoke_git_command(*merge_spec):
        raise GitError("Message rewriting requires linear history; the range contains merge commits.")
    return RewriteRange(branch, base, commits)


def get_commit_message_text(commit: str) -> str:
    """Returns one commit's full message."""
    return "\n".join(invoke_git_command("show", "-s", "--format=%B", commit))


def check_message_script(commit_message_skill: Path) -> Path:
    """The commit-message skill's checker: its Python port when present, else the original it still ships."""
    for suffix in (".py", ".ps1"):
        candidate = commit_message_skill / "scripts" / f"check-message{suffix}"
        if candidate.is_file():
            return candidate.resolve()
    expected = commit_message_skill / "scripts" / "check-message.py"
    raise GitError(f"--commit-message-skill must be the commit-message folder; '{expected}' is missing.")


def run_message_check(script: Path, message: str, label: str) -> tuple[int, list[str]]:
    """Runs the checker and returns its exit code and printed lines."""
    arguments = ["-Message", message, "-Label", label, "-Quiet"]
    command = [sys.executable, str(script), *arguments]
    if script.suffix == ".ps1":
        command = ["pwsh", "-NoProfile", "-NonInteractive", "-File", str(script), *arguments]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    return result.returncode, result.stdout.splitlines()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--range", "-Range")
    parser.add_argument("--from-root", "-FromRoot", action="store_true")
    parser.add_argument("--failing-only", "-FailingOnly", action="store_true")
    # commit-message's folder, passed by the agent because skills need not sit side by side.
    parser.add_argument("--commit-message-skill", "-CommitMessageSkill", required=True, type=Path)
    args = parser.parse_args()
    try:
        checker = check_message_script(args.commit_message_skill)
        target = resolve_rewrite_range(args.range, args.from_root, allow_dirty=True)
    except (OSError, GitError) as error:
        print(error, file=sys.stderr)
        return 1

    failing = 0
    for commit in target.commits:
        short = git_output("rev-parse", "--short", commit)
        message = get_commit_message_text(commit)
        subject = message.split("\n")[0]
        code, report = run_message_check(checker, message, f"{short} {subject}")
        broken = code != 0

        if broken:
            failing += 1
        if args.failing_only and not broken:
            continue

        if not report:
            print(f"{short} {subject}")
        else:
            for line in report:
                print(line)

    print("")
    print(f"{len(target.commits)} commit(s) checked, {failing} need rewriting.")
    if failing > 0:
        print("Write replacements to a directory as <sha>.txt, then run rewrite-messages.py.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
