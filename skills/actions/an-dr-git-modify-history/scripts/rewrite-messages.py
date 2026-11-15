"""Replace commit messages across a linear range, changing nothing else."""

from __future__ import annotations

import argparse
import datetime as dt
import os
import subprocess
import sys
import tempfile
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


def run_message_check(script: Path, message: str, label: str) -> int:
    """Runs the checker with its output on the console and returns its exit code."""
    arguments = ["-Message", message, "-Label", label, "-Quiet"]
    command = [sys.executable, str(script), *arguments]
    if script.suffix == ".ps1":
        command = ["pwsh", "-NoProfile", "-NonInteractive", "-File", str(script), *arguments]
    return subprocess.run(command, check=False).returncode


def set_environment_value(name: str, value: str | None) -> None:
    if not value:
        os.environ.pop(name, None)
    else:
        os.environ[name] = value


METADATA_KEYS = (
    "GIT_AUTHOR_NAME",
    "GIT_AUTHOR_EMAIL",
    "GIT_AUTHOR_DATE",
    "GIT_COMMITTER_NAME",
    "GIT_COMMITTER_EMAIL",
    "GIT_COMMITTER_DATE",
)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--message-directory", "-MessageDirectory", required=True, type=Path)
    parser.add_argument("--range", "-Range")
    parser.add_argument("--from-root", "-FromRoot", action="store_true")
    # commit-message's folder, passed by the agent because skills need not sit side by side.
    parser.add_argument("--commit-message-skill", "-CommitMessageSkill", required=True, type=Path)
    args = parser.parse_args()

    try:
        checker = check_message_script(args.commit_message_skill)
        if not args.message_directory.is_dir():
            raise GitError(f"Message directory '{args.message_directory}' does not exist.")
        target = resolve_rewrite_range(args.range, args.from_root)
    except (OSError, GitError) as error:
        print(error, file=sys.stderr)
        return 1

    # Resolve every <sha>.txt to a full hash and reject anything outside the range.
    replacements: dict[str, str] = {}
    for file in sorted(args.message_directory.glob("*.txt")):
        key = file.stem
        resolved = subprocess.run(
            ["git", "rev-parse", "--verify", "--quiet", f"{key}^{{commit}}"],
            capture_output=True,
            text=True,
            check=False,
        )
        commit = resolved.stdout.strip()
        if resolved.returncode != 0 or not commit:
            print(f"File '{file.name}' does not name a commit.", file=sys.stderr)
            return 1
        if commit not in target.commits:
            print(f"Commit '{key}' lies outside the selected range.", file=sys.stderr)
            return 1
        replacements[commit] = file.read_text(encoding="utf-8-sig")
    if not replacements:
        print(f"No <sha>.txt messages found in '{args.message_directory}'.", file=sys.stderr)
        return 1

    # Validate every replacement before touching history.
    error_count = 0
    for commit, message in replacements.items():
        short = git_output("rev-parse", "--short", commit)
        if run_message_check(checker, message, f"{short} replacement:"):
            error_count += 1
    if error_count > 0:
        print(f"{error_count} replacement(s) break the format; history was not touched.")
        return 1

    old_tip = git_output("rev-parse", "HEAD")
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_ref = f"refs/backup/an-dr-git-modify-history/{target.branch}/{stamp}"
    invoke_git_command("update-ref", backup_ref, old_tip)

    descriptor, message_path = tempfile.mkstemp(prefix="rewrite-message-", suffix=".txt")
    os.close(descriptor)
    message_file = Path(message_path)
    saved_metadata = {key: os.environ.get(key) for key in METADATA_KEYS}
    new_parent = target.base_commit
    rewritten = 0

    try:
        for commit in target.commits:
            tree = git_output("rev-parse", f"{commit}^{{tree}}")
            if commit in replacements:
                message = replacements[commit]
                rewritten += 1
            else:
                message = get_commit_message_text(commit)
            if not message.endswith("\n"):
                message += "\n"
            message_file.write_text(message, encoding="utf-8", newline="")

            metadata = {
                "GIT_AUTHOR_NAME": git_output("show", "-s", "--format=%an", commit),
                "GIT_AUTHOR_EMAIL": git_output("show", "-s", "--format=%ae", commit),
                "GIT_AUTHOR_DATE": git_output("show", "-s", "--format=%aI", commit),
                "GIT_COMMITTER_NAME": git_output("show", "-s", "--format=%cn", commit),
                "GIT_COMMITTER_EMAIL": git_output("show", "-s", "--format=%ce", commit),
                "GIT_COMMITTER_DATE": git_output("show", "-s", "--format=%cI", commit),
            }
            for key, value in metadata.items():
                set_environment_value(key, value)
            try:
                arguments = ["commit-tree", tree]
                if new_parent:
                    arguments += ["-p", new_parent]
                arguments += ["-F", message_path]
                new_parent = git_output(*arguments)
            finally:
                for key in METADATA_KEYS:
                    set_environment_value(key, saved_metadata[key])

        invoke_git_command("update-ref", f"refs/heads/{target.branch}", new_parent or "", old_tip)
    finally:
        for key in METADATA_KEYS:
            set_environment_value(key, saved_metadata[key])
        message_file.unlink(missing_ok=True)

    invoke_git_command("reset", "--mixed", "HEAD")

    # Only messages may have changed, so the new tip must match the old one exactly.
    if subprocess.run(["git", "diff", "--quiet", old_tip, "HEAD"], check=False).returncode != 0:
        print(f"Content changed during the rewrite. Restore with: git reset --hard {old_tip}", file=sys.stderr)
        return 1
    try:
        assert_git_clean_working_tree()
    except GitError as error:
        print(error, file=sys.stderr)
        return 1

    print(f"Rewrote {rewritten} message(s) on '{target.branch}'; content is unchanged.")
    print(f"New tip: {new_parent}")
    print(f"Backup ref: {backup_ref} (restore with git reset --hard {backup_ref})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
