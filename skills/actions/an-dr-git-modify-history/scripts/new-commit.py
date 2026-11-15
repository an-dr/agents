"""Compose, validate, and record a commit in one call."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path


class GitError(Exception):
    """A Git operation that cannot continue."""


def check_message_script(commit_message_skill: Path) -> Path:
    """The commit-message skill's checker: its Python port when present, else the original it still ships."""
    for suffix in (".py", ".ps1"):
        candidate = commit_message_skill / "scripts" / f"check-message{suffix}"
        if candidate.is_file():
            return candidate.resolve()
    expected = commit_message_skill / "scripts" / "check-message.py"
    raise GitError(f"--commit-message-skill must be the commit-message folder; '{expected}' is missing.")


def compose_message(
    commit_type: str,
    scope: str | None,
    summary: str,
    footer: str | None,
    breaking: bool,
    entries: list[str],
) -> str:
    """Assembles the subject, body entries, and footers the format expects."""
    subject = commit_type
    if scope:
        subject += f"({scope})"
    if breaking:
        subject += "!"
    subject += f": {summary}"

    parts = [subject]
    body = []
    for entry in entries:
        if not entry.strip():
            continue
        text = entry.strip()
        body.append(text if re.match(r"^- ", text) else f"- {text}")
    if body:
        parts.append("")
        parts.extend(body)

    footers = []
    for line in (footer or "").replace("\r\n", "\n").split("\n"):
        if line.strip():
            footers.append(line)
    if breaking and not any(re.match(r"^BREAKING CHANGE: ", line) for line in footers):
        raise GitError('A breaking change needs a --footer "BREAKING CHANGE: <consequence>".')
    if footers:
        parts.append("")
        parts.extend(line.strip() for line in footers)

    return "\n".join(parts) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--type", "-Type", required=True)
    parser.add_argument("--scope", "-Scope")
    parser.add_argument("--summary", "-Summary", required=True)
    parser.add_argument("--footer", "-Footer")
    parser.add_argument("--breaking", "-Breaking", action="store_true")
    parser.add_argument("--amend", "-Amend", action="store_true")
    parser.add_argument("--dry-run", "-DryRun", action="store_true")
    # commit-message's folder; its checker validates the assembled message.
    parser.add_argument("--commit-message-skill", "-CommitMessageSkill", required=True, type=Path)
    # Body entries follow the named parameters, one argument each, written without the
    # '- ' marker so the shell cannot read them as flags.
    parser.add_argument("entry", nargs="*")
    args = parser.parse_args()

    try:
        checker = check_message_script(args.commit_message_skill)
        message = compose_message(args.type, args.scope, args.summary, args.footer, args.breaking, args.entry)
    except (OSError, GitError) as error:
        print(error, file=sys.stderr)
        return 1

    arguments = ["-Message", message, "-Quiet"]
    command = [sys.executable, str(checker), *arguments]
    if checker.suffix == ".ps1":
        command = ["pwsh", "-NoProfile", "-NonInteractive", "-File", str(checker), *arguments]
    check = subprocess.run(command, check=False)
    check_failed = check.returncode != 0
    print(message, flush=True)
    if check_failed:
        print("The message breaks the format; nothing was committed.")
        return 1
    if args.dry_run:
        print("Dry run: nothing was committed.")
        return 0

    staged = subprocess.run(["git", "diff", "--cached", "--name-only"], capture_output=True, text=True, check=False)
    if staged.returncode != 0:
        print("git diff --cached failed. See Git output above.", file=sys.stderr)
        return 1
    if not staged.stdout.strip() and not args.amend:
        print("Nothing is staged. Stage the change first.", file=sys.stderr)
        return 1

    descriptor, message_path = tempfile.mkstemp(prefix="commit-message-", suffix=".txt")
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as stream:
            stream.write(message)
        commit = ["git", "commit", "-F", message_path]
        if args.amend:
            commit.append("--amend")
        if subprocess.run(commit, check=False).returncode != 0:
            print("git commit failed. See Git output above.", file=sys.stderr)
            return 1
    finally:
        Path(message_path).unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
