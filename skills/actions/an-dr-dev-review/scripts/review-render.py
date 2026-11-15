"""Render canonical review JSON as one deterministic, self-contained HTML page."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
import uuid
from pathlib import Path


class ReviewError(Exception):
    """A review operation that cannot continue."""


# Copied helpers, owned by this skill: a skill's scripts run standalone and no module
# is shared between skills, so each script carries the part of Review.Common it needs.
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


# https://learn.microsoft.com/dotnet/api/system.net.webutility.htmlencode writes the five
# markup characters as named entities, Latin-1 as decimal entities, and a code point above
# the basic plane as a decimal entity; every other character stays literal.
MARKUP = {"<": "&lt;", ">": "&gt;", "&": "&amp;", '"': "&quot;", "'": "&#39;"}


def html_encode(value: str) -> str:
    """Escapes a value the way the review page's output expects."""
    encoded = []
    for character in value:
        number = ord(character)
        if number < 160:
            encoded.append(MARKUP.get(character, character))
        elif number < 256 or number > 0xFFFF:
            encoded.append(f"&#{number};")
        else:
            encoded.append(character)
    return "".join(encoded)


def convert_to_review_html(value: str) -> str:
    """Escapes note text for HTML and renders `backtick` spans as inline code."""
    escaped = html_encode(re.sub(r"[\r\n]+", " ", value).strip())
    return re.sub(r"`+([^`]+?)`+", r"<code>\1</code>", escaped)


def finding_section_html(title: str, level: str, notes: list) -> list[str]:
    """Renders one finding section with a fixed heading, or an explicit empty state."""
    html = [f"<section><h2>{title}</h2>"]
    if not notes:
        html.append('<p class="ck-quiet">None.</p>')
    for note in notes:
        location = html_encode(str(note.get("file") or ""))
        if note.get("line"):
            location = f"{location}:{note['line']}"
        html.append(f'<article class="finding ck-item {level}" id="{note["id"]}">')
        html.append(
            f'<div class="head"><span class="ck-badge {level}">{note["id"]}</span>'
            f'<span class="loc">{location}</span></div>'
        )
        html.append(f"<p>{convert_to_review_html(str(note['text'] or ''))}</p>")
        if "diagram" in note:
            html.append(f'<div class="diagram"><pre class="mermaid">{html_encode(str(note["diagram"] or ""))}</pre></div>')
        html.append(
            f'<p class="fix"><span class="tag">Fix</span> {convert_to_review_html(str(note["recommendation"] or ""))}</p>'
        )
        html.append("</article>")
    html.append("</section>")
    return html


STYLE = """<style>
:root { --bg: var(--brand-bg); --paper: var(--brand-paper); --ink: var(--brand-ink); --muted: var(--brand-muted);
  --rule: var(--brand-rule); --code: var(--brand-code); }
body { margin: 0; font-size: 16px; line-height: 1.6; }
main { max-width: 880px; margin: 0 auto; padding: 40px 16px 80px; display: grid; gap: 32px; }
h1, h2 { margin: 0; line-height: 1.2; } h1 { font-size: 1.9rem; } h2 { font-size: 1.3rem; }
p { margin: 0; } section { display: grid; gap: 12px; }
code, .loc, .id, .meta { font-family: var(--brand-mono); }
code { font-size: .88em; background: var(--code); padding: .1em .35em; border-radius: 4px; overflow-wrap: anywhere; }
.meta { color: var(--muted); font-size: .85rem; display: flex; flex-wrap: wrap; gap: 4px 18px; }
.verdict, .finding { background: var(--paper); border: 1px solid var(--rule); border-radius: 8px; display: grid; gap: 8px; }
.verdict { padding: 16px 18px; } .finding { padding: 14px 16px; }
.verdict .decision { font-weight: 700; font-size: 1.2rem; color: var(--ck); }
.verdict.ck-ok .decision { font-weight: 400; }
.tally { display: flex; flex-wrap: wrap; gap: 8px; }
.head { display: flex; flex-wrap: wrap; gap: 4px 12px; align-items: baseline; }
.loc { font-size: .8rem; color: var(--muted); overflow-wrap: anywhere; }
.fix { padding-top: 8px; border-top: 1px dashed var(--rule); }
.tag { font-size: .75rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
details.ck-quiet { display: grid; gap: 8px; }
.diagram { overflow-x: auto; background: var(--bg); border: 1px solid var(--rule); border-radius: 6px; padding: 12px; }
.diagram pre { margin: 0; }
</style></head><body><main>"""

# Each section's dark-cockpit level: only critical findings are red, positives stay unlit.
LEVELS = (("critical", "ck-critical"), ("high", "ck-high"), ("slop", "ck-high"), ("improvement", "ck-notice"), ("positive", "ck-ok"))


def render_review(review: dict) -> str:
    """Builds the whole page for one validated review record."""
    sections = review["sections"]
    counts = {
        "critical": len(review_notes(sections["critical"])),
        "high": len(review_notes(sections["high"])),
        "slop": len(review_notes(sections["slop"])),
        "improvement": len(review_notes(sections["improvements"])),
        "positive": len(review_notes(sections["positives"])),
    }
    reference = html_encode(review["reference"])
    decision = html_encode(review["verdict"]["decision"])

    html = ["<!doctype html>"]
    html.append('<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">')
    html.append(f"<title>Code review — {reference}</title>")
    html.append(STYLE)
    # A critical finding outranks whatever decision was recorded beside it.
    if counts["critical"] > 0:
        verdict_level = "ck-critical"
    else:
        verdict_level = {
            "approve": "ck-ok",
            "approve-with-comments": "ck-notice",
            "pending": "ck-info",
        }.get(review["verdict"]["decision"], "ck-high")
    html.append(f"<header><h1>Code review — {reference}</h1>")
    html.append(
        f'<div class="meta"><span>Scope: {html_encode(review["scope"])}</span>'
        f'<span>Review: {html_encode(review["reviewId"])}</span></div></header>'
    )
    html.append(f'<div class="verdict ck-item {verdict_level}"><span class="tag">Verdict</span><span class="decision">{decision}</span>')
    html.append(f"<p>{convert_to_review_html(str(review['verdict']['rationale'] or ''))}</p>")
    html.append('<div class="tally">')
    for key, level in LEVELS:
        chip_level = "ck-ok" if counts[key] == 0 else level
        html.append(f'<span class="ck-badge {chip_level}">{counts[key]} {key}</span>')
    html.append("</div></div>")
    html.append("<section><h2>Summary</h2>")
    html.append(
        f"<p>{convert_to_review_html(str(review['summary'] or '')) if review['summary'] else 'Not set.'}</p></section>"
    )
    html.extend(finding_section_html("Critical — must fix before integration", "ck-critical", review_notes(sections["critical"])))
    html.extend(finding_section_html("High", "ck-high", review_notes(sections["high"])))
    html.extend(finding_section_html("Slop", "ck-high", review_notes(sections["slop"])))
    html.extend(finding_section_html("Improvements", "ck-notice", review_notes(sections["improvements"])))
    # Positives are normal state: present for the reader who looks, collapsed so they do not compete.
    html.append("<section><h2>Positives</h2>")
    positives = review_notes(sections["positives"])
    if not positives:
        html.append('<p class="ck-quiet">None recorded.</p>')
    else:
        html.append(f'<details class="ck-quiet"><summary>{len(positives)} recorded</summary>')
        for note in positives:
            html.append(
                f'<article class="finding ck-item ck-ok" id="{note["id"]}"><div class="head">'
                f'<span class="ck-badge ck-ok">{note["id"]}</span></div>'
                f"<p>{convert_to_review_html(note['text'])}</p></article>"
            )
        html.append("</details>")
    html.append("</section>")
    html.append("</main></body></html>")
    return os.linesep.join(html)


def dependency_script(skill: Path, parameter: str, name: str) -> Path:
    """A dependency's public script: its Python port when it has one, else the original it still ships."""
    for suffix in (".py", ".ps1"):
        candidate = skill / "scripts" / f"{name}{suffix}"
        if candidate.is_file():
            return candidate.resolve()
    raise ReviewError(f"--{parameter} has no scripts/{name}.py; pass that skill's folder.")


def run_dependency_script(script: Path, *arguments: str) -> None:
    command = [sys.executable, str(script), *arguments]
    if script.suffix == ".ps1":
        command = ["pwsh", "-NoProfile", "-NonInteractive", "-File", str(script), *arguments]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        raise ReviewError(f"{script.name} failed: {detail}" if detail else f"{script.name} failed.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--review-path", "-ReviewPath", required=True, type=Path)
    # These skills' folders, passed by the agent because skills need not sit side by side.
    parser.add_argument("--html-report-skill", "-HtmlReportSkill", required=True, type=Path)
    parser.add_argument("--html-style-skill", "-HtmlStyleSkill", required=True, type=Path)
    parser.add_argument("--artifact-layout-skill", "-ArtifactLayoutSkill", required=True, type=Path)
    parser.add_argument("--output-path", "-OutputPath")
    args = parser.parse_args()
    try:
        resolved_path = resolve_review_path(args.review_path)
        review = read_review_json(resolved_path)
        if not args.output_path:
            output_path = resolved_path.with_suffix(".html")
        else:
            output_path = Path(args.output_path)
            if not output_path.is_absolute():
                output_path = Path.cwd() / output_path
        output_path = Path(os.path.abspath(output_path))
        if os.path.normcase(str(output_path.parent)) != os.path.normcase(str(resolved_path.parent)):
            raise ReviewError("The rendered review must remain beside its JSON.")
        if output_path.suffix.lower() != ".html":
            raise ReviewError("The rendered review is HTML; --output-path must end in .html.")

        write_review_text(render_review(review), output_path)
        # Neutral colours come from the report brand, severity colours from the dark-cockpit
        # sheet, and diagrams become inline SVG through the HTML report skill's pinned,
        # offline Mermaid build.
        run_dependency_script(dependency_script(args.html_style_skill, "html-style-skill", "embed-brand"), "-Path", str(output_path))
        run_dependency_script(dependency_script(args.html_report_skill, "html-report-skill", "embed-cockpit"), "-Path", str(output_path))
        run_dependency_script(dependency_script(args.html_report_skill, "html-report-skill", "render-mermaid"), "-Path", str(output_path))
    except (OSError, ReviewError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        return 1
    print(output_path, flush=True)
    # The newest review is also copied to code-review-latest.* for the reader who opens it by name.
    publisher = get_artifact_layout_script(args.artifact_layout_skill, "publish-latest.py")
    result = subprocess.run([sys.executable, str(publisher), str(resolved_path)], check=False)
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
