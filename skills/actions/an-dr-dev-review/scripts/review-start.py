"""Create a canonical JSON review in REPO/.tmp-ai-gen/code-review/."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
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


def get_artifact_layout_script(artifact_layout_skill: Path, name: str) -> Path:
    """Resolves one of artifact-layout's scripts, the one implementation of the layout."""
    path = artifact_layout_skill / "scripts" / name
    if not path.is_file():
        raise ReviewError(f"--artifact-layout-skill has no scripts/{name}; pass an-dr-convention-artifact-layout's folder.")
    return path.resolve()


def new_review_path(repository_root: Path, artifact_layout_skill: Path) -> Path:
    """Takes a new code-review JSON path from artifact-layout."""
    script = get_artifact_layout_script(artifact_layout_skill, "new-artifact-path.py")
    result = subprocess.run(
        [sys.executable, str(script), "code-review", "json", "--repository-root", str(repository_root)],
        capture_output=True,
        text=True,
        check=False,
    )
    lines = [line for line in result.stdout.splitlines() if line.strip()]
    if not lines:
        raise ReviewError("artifact-layout returned no path for this review.")
    return Path(lines[-1].strip())


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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", "-Reference", required=True)
    parser.add_argument("--scope", "-Scope", required=True, choices=("direct", "verify", "summary", "requested"))
    # artifact-layout's folder, passed by the agent because skills need not sit side by side.
    parser.add_argument("--artifact-layout-skill", "-ArtifactLayoutSkill", required=True, type=Path)
    args = parser.parse_args()
    try:
        repository_root = get_review_repository_root()
        review_path = new_review_path(repository_root, args.artifact_layout_skill)
        if review_path.exists():
            raise ReviewError(f"Review already exists: {review_path}")
        template_path = Path(__file__).resolve().parent.parent / "assets" / "review-template.json"
        review = json.loads(template_path.read_text(encoding="utf-8-sig"))
        now = review_timestamp()
        review["reviewId"] = review_path.stem
        review["reference"] = args.reference
        review["scope"] = args.scope
        review["createdAt"] = now
        review["updatedAt"] = now
        write_review_json(review, review_path)
    except (OSError, ReviewError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        return 1
    print(review_path)
    print("JSON and HTML artifacts remain local; .tmp-ai-gen ignores itself.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
