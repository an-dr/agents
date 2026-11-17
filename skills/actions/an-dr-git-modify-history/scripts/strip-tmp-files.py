"""Remove tmp files from every commit after a base, keeping them on disk as untracked files."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path


class Failure(Exception):
    """The strip cannot go on."""


# Work files: any file or folder whose name starts with tmp- or .tmp-, at any depth.
TMP_PATHSPEC = (":(glob)**/tmp-*", ":(glob)**/tmp-*/**", ":(glob)**/.tmp-*", ":(glob)**/.tmp-*/**")
EXCLUDE_TMP = tuple(spec.replace(":(glob)", ":(exclude,glob)") for spec in TMP_PATHSPEC)
META_KEYS = ("GIT_AUTHOR_NAME", "GIT_AUTHOR_EMAIL", "GIT_AUTHOR_DATE",
             "GIT_COMMITTER_NAME", "GIT_COMMITTER_EMAIL", "GIT_COMMITTER_DATE")


def git(*arguments: str, env: dict[str, str] | None = None) -> str:
    """Run Git and raise with its output on any nonzero exit."""
    result = subprocess.run(["git", *arguments], capture_output=True, text=True, encoding="utf-8",
                            errors="replace", check=False, env=env)
    if result.returncode:
        raise Failure(f"git {' '.join(arguments)} failed: {result.stderr.strip()}")
    return result.stdout


def strip(base: str) -> None:
    branch = git("branch", "--show-current").strip()
    if not branch:
        raise Failure("Stripping tmp files needs a checked-out branch, not detached HEAD.")
    if git("status", "--porcelain", "--", ".", *EXCLUDE_TMP).strip():
        raise Failure("The working tree has changes beyond tmp files; commit or stash them first.")
    merge_base = git("merge-base", base, "HEAD").strip()
    paths = sorted({p for p in git("log", "--format=", "--name-only", f"{merge_base}..HEAD", "--", *TMP_PATHSPEC).splitlines() if p})
    if not paths:
        print("No commit after the base carries a tmp file; nothing to strip.")
        return
    if git("rev-list", "--min-parents=2", f"{merge_base}..HEAD").strip():
        raise Failure("Stripping tmp files needs linear history; rebase away merge commits first.")

    old_tip = git("rev-parse", "HEAD").strip()
    parent = merge_base
    rewritten = dropped = 0
    index = os.path.join(tempfile.gettempdir(), f"strip-tmp-{uuid.uuid4()}.index")
    env = {**os.environ, "GIT_INDEX_FILE": index}
    try:
        for commit in git("rev-list", "--reverse", f"{merge_base}..HEAD").split():
            git("read-tree", commit, env=env)
            git("rm", "-r", "--cached", "--quiet", "--ignore-unmatch", "--", *TMP_PATHSPEC, env=env)
            tree = git("write-tree", env=env).strip()
            if tree == git("rev-parse", f"{parent}^{{tree}}").strip():
                dropped += 1
                continue
            meta = git("show", "-s", "--format=%an%x00%ae%x00%aI%x00%cn%x00%ce%x00%cI", commit).rstrip("\n").split("\0")
            message = git("show", "-s", "--format=%B", commit)
            parent = subprocess.run(
                ["git", "commit-tree", tree, "-p", parent, "-F", "-"], input=message, capture_output=True,
                text=True, encoding="utf-8", check=True, env={**env, **dict(zip(META_KEYS, meta))},
            ).stdout.strip()
            rewritten += 1
    finally:
        Path(index).unlink(missing_ok=True)
    git("update-ref", f"refs/heads/{branch}", parent, old_tip)
    # The index still describes the old tip; a mixed reset re-reads HEAD and
    # leaves the tmp files in the working tree, now untracked.
    git("reset", "--quiet", "--mixed", "HEAD")
    print(f"Stripped {len(paths)} tmp path(s): {rewritten} commit(s) rewritten, {dropped} tmp-only commit(s) dropped. "
          "The files stay on disk, untracked.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", "-Base", required=True, help="the branch or commit the work started from")
    args = parser.parse_args()
    try:
        strip(args.base)
    except (OSError, subprocess.CalledProcessError, Failure) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
