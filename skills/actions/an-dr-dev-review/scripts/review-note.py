"""Add a numbered note or update a singleton review section."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path


class ReviewError(Exception):
    """A review operation that cannot continue."""


# Copied helpers, owned by this skill: a skill's scripts run standalone and no module
# is shared between skills, so each script carries the part of Review.Common it needs.
def review_timestamp() -> str:
    """The current UTC time in the round-trip form the review schema expects."""
    seconds, nanoseconds = divmod(time.time_ns(), 1_000_000_000)
    stamp = dt.datetime.fromtimestamp(seconds, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S")
    return f"{stamp}.{nanoseconds // 100:07d}Z"


def get_review_repository_root() -> Path:
    """Returns the root of the repository being reviewed."""
    result = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False)
    root = result.stdout.strip()
    if result.returncode != 0 or not root:
        raise ReviewError("Run review scripts inside the repository being reviewed.")
    return Path(root)


def assert_review_properties(value: object, expected: tuple[str, ...], name: str, optional: tuple[str, ...] = ()) -> None:
    """Rejects missing and unknown JSON object properties."""
    actual = list(value) if isinstance(value, dict) else []
    missing = [key for key in expected if key not in actual]
    unknown = [key for key in actual if key not in expected and key not in optional]
    if missing:
        raise ReviewError(f"{name} is missing properties: {', '.join(missing)}.")
    if unknown:
        raise ReviewError(f"{name} contains unknown properties: {', '.join(unknown)}.")


def assert_review_timestamp(value: object, name: str) -> None:
    """Accepts a typed date or a parseable timestamp string."""
    if isinstance(value, (dt.datetime, dt.date)):
        return
    if not isinstance(value, str):
        raise ReviewError(f"Review JSON contains an invalid '{name}' timestamp.")
    text = value.strip()
    if text.endswith(("Z", "z")):
        text = f"{text[:-1]}+00:00"
    try:
        dt.datetime.fromisoformat(text)
    except ValueError as error:
        raise ReviewError(f"Review JSON contains an invalid '{name}' timestamp.") from error


def review_notes(value: object) -> list:
    return value if isinstance(value, list) else [value]


def assert_review_notes(notes: list, prefix: str, positive: bool = False) -> None:
    """Validates one numbered finding or positive-note collection."""
    expected_number = 1
    for note in notes:
        expected_properties = ("id", "text", "addedAt") if positive else ("id", "file", "line", "text", "recommendation", "addedAt")
        # A finding may carry Mermaid source that explains it; positives never do.
        optional_properties = () if positive else ("diagram",)
        assert_review_properties(note, expected_properties, f"Review note {expected_number}", optional_properties)
        expected_id = f"{prefix}.{expected_number}"
        if not isinstance(note, dict) or note.get("id") != expected_id:
            raise ReviewError(f"Expected review note ID '{expected_id}', found '{note.get('id') if isinstance(note, dict) else None}'.")
        if not str(note.get("text") or "").strip():
            raise ReviewError(f"Review note '{expected_id}' has no text.")
        assert_review_timestamp(note.get("addedAt"), f"{expected_id} addedAt")
        if not positive:
            if not str(note.get("file") or "").strip():
                raise ReviewError(f"Review finding '{expected_id}' has no file.")
            file = str(note["file"]).replace("\\", "/")
            if os.path.isabs(file) or ".." in file.split("/"):
                raise ReviewError(f"Review finding '{expected_id}' must use a repository-relative file path.")
            if not str(note.get("recommendation") or "").strip():
                raise ReviewError(f"Review finding '{expected_id}' has no recommendation.")
            line = note.get("line")
            if line is not None and (not isinstance(line, int) or isinstance(line, bool) or line < 1):
                raise ReviewError(f"Review finding '{expected_id}' has an invalid line number.")
            if "diagram" in note and not str(note["diagram"] or "").strip():
                raise ReviewError(f"Review finding '{expected_id}' has an empty diagram.")
        expected_number += 1


def assert_review_json(review: object) -> None:
    """Validates the complete canonical review schema and controlled values."""
    assert_review_properties(
        review,
        ("schemaVersion", "reviewId", "reference", "scope", "createdAt", "updatedAt", "summary", "sections", "verdict"),
        "Review JSON",
    )
    if review.get("schemaVersion") != 1:
        raise ReviewError(f"Unsupported review schema version '{review.get('schemaVersion')}'.")
    for property_name in ("reviewId", "reference", "scope", "createdAt", "updatedAt"):
        if not str(review.get(property_name) or "").strip():
            raise ReviewError(f"Review JSON is missing '{property_name}'.")
    if review.get("scope") not in ("direct", "verify", "summary", "requested"):
        raise ReviewError(f"Unsupported review scope '{review.get('scope')}'.")
    for timestamp in ("createdAt", "updatedAt"):
        assert_review_timestamp(review.get(timestamp), timestamp)
    sections = review.get("sections")
    verdict = review.get("verdict")
    if sections is None or verdict is None:
        raise ReviewError("Review JSON is missing sections or verdict.")
    assert_review_properties(sections, ("critical", "high", "slop", "improvements", "positives"), "Review sections")
    assert_review_properties(verdict, ("decision", "rationale"), "Review verdict")
    for name in ("critical", "high", "slop", "improvements", "positives"):
        if sections.get(name) is None:
            raise ReviewError(f"Review JSON is missing sections.{name}.")
    assert_review_notes(review_notes(sections["critical"]), "CR")
    assert_review_notes(review_notes(sections["high"]), "HI")
    assert_review_notes(review_notes(sections["slop"]), "SL")
    assert_review_notes(review_notes(sections["improvements"]), "IM")
    assert_review_notes(review_notes(sections["positives"]), "PO", positive=True)
    if verdict.get("decision") not in ("pending", "approve", "approve-with-comments", "changes-required"):
        raise ReviewError(f"Unsupported review verdict '{verdict.get('decision')}'.")
    if verdict.get("decision") != "pending" and not str(verdict.get("rationale") or "").strip():
        raise ReviewError("A completed verdict requires a rationale.")


def read_review_json(path: Path) -> dict:
    """Reads and validates canonical review JSON."""
    if not path.exists():
        raise ReviewError(f"Review JSON does not exist: {path}")
    review = json.loads(path.read_text(encoding="utf-8-sig"))
    if review.get("scope") == "mr":
        review["scope"] = "summary"
    # Reviews recorded before the slop section existed read as having none.
    sections = review.get("sections")
    if isinstance(sections, dict) and "slop" not in sections:
        sections["slop"] = []
    assert_review_json(review)
    expected_name = f"{review['reviewId']}.json"
    if path.name != expected_name:
        raise ReviewError(f"Review filename must match reviewId: {expected_name}")
    return review


def resolve_review_path(path: Path) -> Path:
    """Validates that canonical JSON stays in the run directory it was created in."""
    repository_root = get_review_repository_root()
    if not path.exists():
        raise ReviewError(f"Review JSON does not exist: {path}")
    resolved = path.resolve()
    # The shape artifact-layout creates; that skill, not this guard, owns the layout.
    expected_directory = repository_root.resolve() / ".tmp-ai-gen" / "code-review"
    if os.path.normcase(str(resolved.parent)) != os.path.normcase(str(expected_directory)):
        raise ReviewError("Review JSON must be directly inside REPO/.tmp-ai-gen/code-review/.")
    if not re.fullmatch(r"code-review-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}(-\d+)?\.json", resolved.name):
        raise ReviewError("Canonical review files are named code-review-<YYYY-MM-DD_hh-mm>.json.")
    return resolved


def write_review_text(text: str, path: Path) -> None:
    """Atomically writes a review artifact beside its destination."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.parent / f".review-{uuid.uuid4()}.tmp"
    try:
        temporary.write_text(text, encoding="utf-8", newline="")
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def write_review_json(review: dict, path: Path) -> None:
    """Validates and atomically writes canonical review JSON."""
    review["updatedAt"] = review_timestamp()
    assert_review_json(review)
    # The record's line endings follow the platform, as the JSON serializer's did.
    text = json.dumps(review, ensure_ascii=False, indent=2).replace("\n", os.linesep)
    write_review_text(text, path)


class ReviewLock:
    """An exclusive local lock for one canonical review file."""

    def __init__(self, path: Path) -> None:
        digest = hashlib.sha256(str(path.resolve()).lower().encode("utf-8")).hexdigest()
        self.path = Path(tempfile.gettempdir()) / f"agents-review-{digest}.lock"
        self.stream = None

    def __enter__(self) -> "ReviewLock":
        try:
            self.stream = self.path.open("a+b")
            if self.path.stat().st_size == 0:
                self.stream.write(b"0")
                self.stream.flush()
            self.stream.seek(0)
            if os.name == "nt":
                import msvcrt

                msvcrt.locking(self.stream.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl

                fcntl.flock(self.stream.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as error:
            if self.stream is not None:
                self.stream.close()
            raise ReviewError("Another process is updating this review. Retry after it finishes.") from error
        return self

    def __exit__(self, *_exc_info: object) -> None:
        if self.stream is None:
            return
        try:
            self.stream.seek(0)
            if os.name == "nt":
                import msvcrt

                msvcrt.locking(self.stream.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl

                fcntl.flock(self.stream.fileno(), fcntl.LOCK_UN)
        finally:
            self.stream.close()
            self.path.unlink(missing_ok=True)


def get_next_note_id(notes: list, prefix: str) -> str:
    """The next free number in one note collection."""
    maximum = 0
    for note in notes:
        identifier = note.get("id") if isinstance(note, dict) else None
        found = re.fullmatch(rf"{re.escape(prefix)}\.(\d+)", str(identifier or ""))
        if found:
            maximum = max(maximum, int(found.group(1)))
    return f"{prefix}.{maximum + 1}"


FINDING_SECTIONS = {
    "critical": ("critical", "CR"),
    "high": ("high", "HI"),
    "slop": ("slop", "SL"),
    "improvement": ("improvements", "IM"),
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--review-path", "-ReviewPath", required=True, type=Path)
    parser.add_argument(
        "--section",
        "-Section",
        required=True,
        choices=("summary", "critical", "high", "slop", "improvement", "positive", "verdict"),
    )
    parser.add_argument("--text", "-Text", required=True)
    parser.add_argument("--file", "-File")
    parser.add_argument("--line", "-Line", type=int)
    parser.add_argument("--recommendation", "-Recommendation")
    parser.add_argument("--decision", "-Decision", choices=("approve", "approve-with-comments", "changes-required"))
    parser.add_argument("--diagram", "-Diagram")
    parser.add_argument("--diagram-path", "-DiagramPath", type=Path)
    args = parser.parse_args()
    try:
        diagram = args.diagram
        if args.diagram and args.diagram_path:
            raise ReviewError("Pass --diagram or --diagram-path, not both.")
        if args.diagram_path:
            if not args.diagram_path.is_file():
                raise ReviewError(f"Diagram file does not exist: {args.diagram_path}")
            diagram = args.diagram_path.resolve().read_text(encoding="utf-8-sig")
        if diagram and args.section not in FINDING_SECTIONS:
            raise ReviewError("Only findings carry a diagram.")
        if args.line is not None and args.line < 1:
            raise ReviewError("--line must be 1 or greater.")

        with ReviewLock(args.review_path):
            resolved_path = resolve_review_path(args.review_path)
            review = read_review_json(resolved_path)
            note_id = None

            if args.section == "summary":
                review["summary"] = args.text
            elif args.section == "verdict":
                if not args.decision:
                    raise ReviewError("--decision is required for the verdict section.")
                review["verdict"]["decision"] = args.decision
                review["verdict"]["rationale"] = args.text
            elif args.section == "positive":
                notes = review_notes(review["sections"]["positives"])
                note_id = get_next_note_id(notes, "PO")
                review["sections"]["positives"] = notes + [
                    {"id": note_id, "text": args.text, "addedAt": review_timestamp()}
                ]
            else:
                if not (args.file or "").strip() or not (args.recommendation or "").strip():
                    raise ReviewError("--file and --recommendation are required for findings.")
                collection, prefix = FINDING_SECTIONS[args.section]
                notes = review_notes(review["sections"][collection])
                note_id = get_next_note_id(notes, prefix)
                finding = {
                    "id": note_id,
                    "file": args.file.replace("\\", "/"),
                    "line": args.line,
                    "text": args.text,
                    "recommendation": args.recommendation,
                    "addedAt": review_timestamp(),
                }
                if diagram:
                    finding["diagram"] = diagram.strip()
                review["sections"][collection] = notes + [finding]

            write_review_json(review, resolved_path)
    except (OSError, ReviewError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        return 1
    if note_id:
        print(f"Added {note_id} to {resolved_path}")
    else:
        print(f"Updated {args.section} in {resolved_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
