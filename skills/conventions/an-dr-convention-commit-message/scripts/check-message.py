"""Validate an existing commit message file, string, or commit.

Suitable as a commit-msg hook: it exits non-zero on any rule violation.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


# --- Copied helpers, owned by an-dr-convention-commit-message -------------------
# These were the GitCommit.Format.psm1 module. They stay in this file as a copy this
# skill owns, so the checker installs alone; a caller needing more runs this script.


@dataclass(frozen=True)
class Violation:
    """One finding about a message."""

    severity: str
    rule: str
    detail: str
    line: int = 1


COMMIT_TYPES = (
    "feat",
    "fix",
    "docs",
    "refactor",
    "test",
    "style",
    "chore",
    "build",
    "ci",
    "perf",
    "revert",
)
SUBJECT_MAX_LENGTH = 72
ENTRY_TARGET_LENGTH = 72
ENTRY_MAX_COUNT = 5
FOOTER_PATTERN = re.compile(r"^(BREAKING CHANGE|[A-Za-z][A-Za-z-]*): \S|^[A-Za-z][A-Za-z-]* #\S")
MARKDOWN_PATTERN = re.compile(r"`|\*\*|\]\(|^#{1,6} ")
SUBJECT_PATTERN = re.compile(r"^(?P<type>[A-Za-z]+)(?:\((?P<scope>[^)]*)\))?(?P<break>!)?: (?P<summary>.*)$")
SCOPE_PATTERN = re.compile(r"[a-z0-9][a-z0-9-]*")
# Trailer keys that credit a second party, and prose that names a tool as the
# author. A tool named as the subject of the work is not attribution and passes.
ATTRIBUTION_TRAILER_PATTERN = re.compile(
    r"^\s*(co-authored-by|co-developed-by|assisted-by|authored-by|generated-by|created-by)\s*:",
    re.IGNORECASE,
)
ATTRIBUTION_TEXT_PATTERN = re.compile(
    r"noreply@anthropic\.com|🤖|"  # the robot emoji marks generated footers
    r"(generated|written|authored|created|produced|assisted)\s+(with|by)\s+(an?\s+|the\s+)?"
    r"(ai\b|a\.i\.|llm\b|agent\b|assistant\b|model\b|bot\b|"
    r"claude|anthropic|copilot|chatgpt|gpt-|openai|gemini|cursor|codex|aider)",
    re.IGNORECASE,
)


def markdown_violation(text: str, rule: str, line: int) -> Violation | None:
    """Return a violation when a line carries Markdown the format forbids."""
    if MARKDOWN_PATTERN.search(text):
        return Violation(
            "error", rule, "Markdown renders literally in git log and GitHub commit views; write it bare.", line
        )
    return None


def declared_scopes(repository_root: Path | str = ".") -> list[str]:
    """Read the host AGENTS.md '## Commit scopes' list. Empty when undeclared."""
    policy = Path(repository_root) / "AGENTS.md"
    if not policy.is_file():
        return []
    scopes = []
    in_section = False
    with open(policy, "r", encoding="utf-8-sig", newline="") as stream:
        lines = stream.read().splitlines()
    for line in lines:
        if re.match(r"^##\s", line):
            in_section = re.fullmatch(r"^##\s+Commit scopes\s*$", line) is not None
            continue
        if in_section:
            match = re.fullmatch(r"^-\s+(?P<scope>[a-z0-9][a-z0-9-]*)\s*$", line)
            if match:
                scopes.append(match.group("scope"))
    return scopes


def subject_violations(subject: str, allowed_scope: tuple[str, ...] | list[str] = ()) -> list[Violation]:
    """Validate the subject line against the format."""
    found = []
    match = SUBJECT_PATTERN.match(subject)
    if not match:
        found.append(
            Violation("error", "subject.shape", f"Subject must read 'type(scope): summary'; got '{subject}'.")
        )
    else:
        commit_type = match.group("type")
        if commit_type not in COMMIT_TYPES:
            found.append(
                Violation("error", "subject.type", f"Type '{commit_type}' is not one of: {', '.join(COMMIT_TYPES)}.")
            )
        if match.group("scope") is not None:
            scope = match.group("scope")
            if not SCOPE_PATTERN.fullmatch(scope):
                found.append(Violation("error", "subject.scope", f"Scope '{scope}' must be lowercase."))
            else:
                # An empty list means the host declares no scopes, so any shape passes.
                allowed = [declared for declared in allowed_scope if declared]
                if allowed and scope not in allowed:
                    found.append(
                        Violation(
                            "error",
                            "subject.scope",
                            "Scope "
                            f"'{scope}' is not declared under '## Commit scopes' in AGENTS.md: "
                            f"{', '.join(allowed)}.",
                        )
                    )
        summary = match.group("summary")
        if not summary.strip():
            found.append(Violation("error", "subject.summary", "The subject has no summary after the colon."))
        else:
            if re.match(r"^[A-Z]", summary):
                found.append(
                    Violation("error", "subject.case", "The summary starts uppercase; the format writes it lowercase.")
                )
            if summary.endswith("."):
                found.append(Violation("error", "subject.period", "The subject ends with a period; drop it."))
    if len(subject) > SUBJECT_MAX_LENGTH:
        found.append(
            Violation(
                "error",
                "subject.length",
                f"The subject is {len(subject)} characters; the limit is {SUBJECT_MAX_LENGTH}.",
            )
        )
    markdown = markdown_violation(subject, "subject.markdown", 1)
    if markdown:
        found.append(markdown)
    return found


def entry_violations(text: str, line: int) -> list[Violation]:
    """Validate one body line as a list entry."""
    found = []
    if not text.strip():
        found.append(
            Violation(
                "error", "body.blank", "The body holds no blank lines; the only blank line separates the footers.", line
            )
        )
        return found
    if not re.match(r"^- ", text):
        found.append(Violation("error", "body.entry", f"Every body line is a '- ' entry; got '{text}'.", line))
        return found
    if not re.match(r"^- [A-Za-z]", text):
        found.append(
            Violation("error", "body.lead", "An entry starts with a letter; rephrase so no punctuation leads.", line)
        )
    if text.endswith("."):
        found.append(Violation("error", "body.period", "An entry takes no trailing period.", line))
    if re.match(r"^- [A-Z]", text):
        found.append(
            Violation("warning", "body.case", "Entries read lowercase unless they lead with an identifier.", line)
        )
    if len(text) > ENTRY_TARGET_LENGTH:
        found.append(
            Violation(
                "warning",
                "body.length",
                f"The entry is {len(text)} characters; entries are never wrapped, so aim for {ENTRY_TARGET_LENGTH}.",
                line,
            )
        )
    markdown = markdown_violation(text, "body.markdown", line)
    if markdown:
        found.append(markdown)
    return found


def commit_message_violations(
    message: str, allowed_scope: tuple[str, ...] | list[str] = ()
) -> list[Violation]:
    """Validate a whole commit message and return violations, errors first."""
    found: list[Violation] = []
    lines = [
        line
        for line in message.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        if not line.startswith("#")
    ]
    while lines and not lines[-1].strip():
        lines.pop()
    if not lines:
        found.append(Violation("error", "message.empty", "The commit message is empty."))
        return found

    found.extend(subject_violations(lines[0], allowed_scope))

    for index, line in enumerate(lines):
        if ATTRIBUTION_TRAILER_PATTERN.search(line) or ATTRIBUTION_TEXT_PATTERN.search(line):
            found.append(
                Violation(
                    "error",
                    "message.attribution",
                    "The author is the person who ran the commit; drop the co-author or AI attribution line.",
                    index + 1,
                )
            )

    if len(lines) == 1:
        return found
    if lines[1].strip():
        found.append(Violation("error", "body.separator", "A blank line separates the subject from the body.", 2))
    if len(lines) < 3:
        return found

    rest = lines[2:]
    body_lines = rest
    blank_index = -1
    for index in range(len(rest) - 1, -1, -1):
        if not rest[index].strip():
            blank_index = index
            break
    if blank_index >= 0:
        candidate = rest[blank_index + 1 :]
        if candidate and all(FOOTER_PATTERN.search(line) for line in candidate):
            body_lines = rest[:blank_index]

    if not body_lines:
        return found

    # A body with no entry markers at all is prose: report it once, not per line.
    entry_lines = [line for line in body_lines if re.match(r"^- ", line)]
    if not entry_lines:
        found.append(
            Violation(
                "error",
                "body.prose",
                f"The body is prose; rewrite it as 1 to {ENTRY_MAX_COUNT} '- ' entries.",
                3,
            )
        )
        return found

    for index, line in enumerate(body_lines):
        found.extend(entry_violations(line, index + 3))
    if len(body_lines) > ENTRY_MAX_COUNT:
        found.append(
            Violation(
                "error",
                "body.count",
                f"The body holds {len(body_lines)} lines; the limit is {ENTRY_MAX_COUNT} entries. "
                "Split the commit or merge points.",
                3,
            )
        )
    return found


def print_violations(violations: list[Violation], label: str) -> None:
    """Print a violation report. Emits nothing when the message is clean."""
    if not violations:
        return
    if label:
        print(label)
    for item in sorted(violations, key=lambda violation: (violation.severity, violation.line)):
        print(f"  {item.severity:<7} line {item.line:<3} {item.rule:<20} {item.detail}")


def error_count(violations: list[Violation]) -> int:
    """Count the blocking violations in a report."""
    return len([violation for violation in violations if violation.severity == "error"])


# --- End of copied helpers ------------------------------------------------------


def read_message(path: Path) -> str:
    with open(path, "r", encoding="utf-8-sig", newline="") as stream:
        return stream.read()


def commit_message(commit: str) -> str:
    result = subprocess.run(
        ["git", "show", "-s", "--format=%B", commit],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise ValueError(f"git show failed for '{commit}'. See Git output above.")
    return "\n".join(result.stdout.splitlines())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("message_file", nargs="?", type=Path, metavar="path", help="a file holding the message, as a commit-msg hook passes")
    parser.add_argument("--path", "-Path", type=Path, help="the same message file, named")
    parser.add_argument("--message", "-Message", default=None, help="the message text")
    parser.add_argument("--commit", "-Commit", default=None, help="a commit whose message is checked")
    parser.add_argument(
        "--label", "-Label", default="Commit message check:", help="heading printed above the violations"
    )
    parser.add_argument("--quiet", "-Quiet", action="store_true", help="print only the violations")
    args = parser.parse_args()
    if args.message_file is not None:
        if args.path is not None:
            parser.error("name the message file once, as an argument or with --path")
        args.path = args.message_file
    chosen = [value for value in (args.path, args.message, args.commit) if value is not None]
    if len(chosen) != 1:
        parser.error("pass exactly one of a message file, --message, or --commit")

    try:
        if args.path is not None:
            if not args.path.exists():
                raise ValueError(f"Message file '{args.path}' does not exist.")
            text = read_message(args.path)
        elif args.message is not None:
            text = args.message
        else:
            text = commit_message(args.commit)
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1

    violations = commit_message_violations(text, declared_scopes())
    print_violations(violations, args.label)
    errors = error_count(violations)
    if errors > 0:
        if not args.quiet:
            print(f"The message breaks {errors} rule(s).")
        return 1
    if not args.quiet:
        print("The commit message matches the format.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
