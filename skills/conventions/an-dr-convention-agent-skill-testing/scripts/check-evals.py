"""Validate evaluation suites and fixture archives without running agents."""

from __future__ import annotations

import argparse
import json
import re
import stat
import sys
import zipfile
from pathlib import Path


ENV_FIELDS = ("host", "model", "os", "tools", "network", "permissions", "discovery", "instructions", "workspace")
BUCKETS = ("explicit", "implicit", "contextual", "negative")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def fields(value: object, allowed: set[str], required: set[str], where: str) -> dict:
    require(isinstance(value, dict), f"{where} must be an object.")
    for key in value:
        require(key in allowed, f"{where} has unknown field '{key}'.")
    for key in required:
        require(key in value, f"{where} is missing '{key}'.")
    return value


def text(value: object, where: str) -> str:
    require(isinstance(value, str) and bool(value.strip()), f"{where} must be nonempty text.")
    return value


def array(value: object, where: str, empty: bool = False) -> list:
    require(isinstance(value, list) and (empty or bool(value)), f"{where} must be a nonempty array (unless explicitly allowed empty).")
    return value


def texts(value: object, where: str, empty: bool = False) -> list[str]:
    result = array(value, where, empty)
    for item in result:
        text(item, f"{where} item")
    return result


def integer(value: object, where: str, positive: bool = False) -> int:
    require(type(value) is int and (not positive or value > 0), f"{where} must be an integer{' greater than zero' if positive else ''}.")
    return value


def safe_path(value: object) -> str:
    value = text(value, "path")
    parts = value.split("/")
    bad = r'[\\:<>"|?*\x00-\x1f]'
    require(not re.search(bad, value) and all(part not in ("", ".", "..", ".git") and not re.search(r"[. ]$", part) and not re.match(r"^(?:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)", part, re.I) for part in parts), f"unsafe path '{value}'.")
    return value


def suite_file(root: Path | None, relative: str) -> Path:
    safe_path(relative)
    require(root is not None, "SuiteRoot is required to validate fixture or grader files.")
    root = root.absolute()
    for ancestor in (root, *root.parents):
        require(not ancestor.is_symlink(), f"Reparse point suite ancestor: {ancestor}")
    current = root
    for part in relative.split("/"):
        current = current / part
        require(current.exists(), f"Missing suite file '{relative}'.")
        require(not current.is_symlink(), f"Reparse point in '{relative}'.")
    require(current.is_file(), f"Not a file: '{relative}'.")
    return current


def environment(value: object, partial: bool = False) -> None:
    value = fields(value, set(ENV_FIELDS), set() if partial else set(ENV_FIELDS), "environment")
    for key in ("host", "model"):
        if key in value:
            text(value[key], f"environment.{key}")
    for key in ("os", "tools", "instructions"):
        if key in value:
            texts(value[key], f"environment.{key}", key == "tools")
    for os_name in value.get("os", []):
        require(os_name in ("windows", "linux", "macos"), f"Unsupported environment.os '{os_name}'.")
    for key, allowed in {"network": ("disabled", "fixture-only"), "permissions": ("workspace-only",), "discovery": ("host-native",), "workspace": ("fresh-git",)}.items():
        if key in value:
            require(value[key] in allowed, f"Invalid environment.{key}.")


def regex(value: object) -> None:
    text(value, "pattern")
    try:
        re.compile(value)
    except re.error as error:
        raise ValueError(f"Invalid regex '{value}'.") from error


def archive(root: Path | None, relative: str, seen: set[str]) -> None:
    require(bool(re.match(r"^fixtures/.+\.zip$", relative)), "fixtures must reference ZIP files under fixtures/.")
    path = suite_file(root, relative)
    with zipfile.ZipFile(path) as source:
        entries = source.infolist()
        require(1 <= len(entries) <= 10000, "Archive must have 1 to 10000 entries.")
        declared = actual = 0
        for entry in entries:
            name = safe_path(entry.filename)
            require(bool(re.match(r"^(?:baseline|working)/.+", name)), f"Archive entry outside baseline/ or working/: {name}")
            mode = (entry.external_attr >> 16) & 0xF000
            require(mode in (0, stat.S_IFREG), f"Archive entry must be an ordinary file: {name}")
            require(not (entry.external_attr & 0x400), f"Archive reparse point: {name}")
            folded = name.casefold()
            require(folded not in seen, f"Archive path collision: {name}")
            seen.add(folded)
            declared += entry.file_size
            require(declared <= 100 * 1024 * 1024, "Archive exceeds 100 MiB uncompressed.")
            size = 0
            decoder = __import__("codecs").getincrementaldecoder("utf-8")("strict")
            with source.open(entry) as stream:
                for chunk in iter(lambda: stream.read(8192), b""):
                    actual += len(chunk)
                    size += len(chunk)
                    require(actual <= 100 * 1024 * 1024, "Archive exceeds 100 MiB uncompressed.")
                    decoder.decode(chunk)
                decoder.decode(b"", final=True)
            require(size == entry.file_size, f"Archive size mismatch: {name}")


def validate(suite: object, root: Path | None) -> int:
    suite = fields(suite, {"schema_version", "skill_name", "environment", "evals"}, {"schema_version", "skill_name", "environment", "evals"}, "suite")
    require(integer(suite["schema_version"], "schema_version") == 1, "schema_version must be integer 1.")
    name = text(suite["skill_name"], "skill_name")
    require(bool(re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name)), "Invalid skill_name.")
    environment(suite["environment"])
    cases = array(suite["evals"], "evals")
    ids = set()
    buckets = set()
    required = {"id", "bucket", "prompt", "expected_skill", "expected_behavior", "assertions", "runs"}
    for case in cases:
        case = fields(case, required | {"context", "fixtures", "follow_up", "environment"}, required, "case")
        case_id = text(case["id"], "case.id")
        prompt = text(case["prompt"], "case.prompt")
        require(case_id.casefold() not in ids, f"Duplicate case ID '{case_id}'.")
        ids.add(case_id.casefold())
        bucket = case["bucket"]
        require(bucket in BUCKETS, "Invalid bucket.")
        buckets.add(bucket)
        if bucket == "negative":
            require(case["expected_skill"] is None, "Negative expected_skill must be null.")
        else:
            require(case["expected_skill"] == name, "Positive expected_skill must match skill_name.")
        if bucket == "explicit":
            require(name in prompt, "Explicit prompt must name skill_name.")
        if bucket in ("implicit", "contextual"):
            require(name not in prompt, "Discovery prompt must not name skill_name.")
        integer(case["runs"], "runs", True)
        texts(case["expected_behavior"], "expected_behavior")
        if "context" in case:
            text(case["context"], "context")
        if "follow_up" in case:
            texts(case["follow_up"], "follow_up")
        if "environment" in case:
            environment(case["environment"], True)
        if "fixtures" in case:
            seen = set()
            for fixture in texts(case["fixtures"], "fixtures"):
                archive(root, fixture, seen)
            for path in seen:
                parts = path.split("/")
                require(all("/".join(parts[:index]) not in seen for index in range(1, len(parts))), f"Archive file/directory collision: {path}")
        for assertion in array(case["assertions"], "assertions"):
            assertion = fields(assertion, set(assertion) if isinstance(assertion, dict) else set(), {"type"}, "assertion")
            kind = assertion["type"]
            contracts = {"invocation_check": {"expected"}, "transcript_check": {"pattern"}, "file_check": {"path", "contains"}, "exit_code": {"command_pattern", "expected"}, "diff_scope": {"allowed_paths"}, "deterministic": {"script"}, "llm_judge": {"rubric"}}
            require(kind in contracts, f"Unknown assertion type '{kind}'.")
            fields(assertion, contracts[kind] | {"type"}, (contracts[kind] - {"contains"}) | {"type"}, "assertion")
            if kind == "invocation_check":
                require(type(assertion["expected"]) is bool, "invocation_check.expected must be boolean.")
            elif kind == "transcript_check":
                regex(assertion["pattern"])
            elif kind == "file_check":
                safe_path(assertion["path"])
                if "contains" in assertion:
                    text(assertion["contains"], "contains")
            elif kind == "exit_code":
                regex(assertion["command_pattern"])
                integer(assertion["expected"], "exit_code.expected")
            elif kind == "diff_scope":
                for path in texts(assertion["allowed_paths"], "allowed_paths", True):
                    safe_path(path)
            elif kind == "deterministic":
                require(bool(re.match(r"^graders/.+\.py$", assertion["script"])), "deterministic script must be under graders/ and end in .py.")
                suite_file(root, assertion["script"])
            elif kind == "llm_judge":
                text(assertion["rubric"], "rubric")
    for bucket in BUCKETS:
        require(bucket in buckets, f"Missing bucket '{bucket}'.")
    return len(cases)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--path", "-Path", type=Path)
    source.add_argument("--json", "-Json")
    parser.add_argument("--suite-root", "-SuiteRoot", type=Path)
    args = parser.parse_args()
    try:
        payload = args.path.read_text(encoding="utf-8-sig") if args.path else args.json
        root = args.path.resolve().parent if args.path else args.suite_root
        count = validate(json.loads(payload), root)
    except (OSError, ValueError, zipfile.BadZipFile, UnicodeError) as error:
        print(error, file=sys.stderr)
        return 1
    print(f"Evaluation structure passed: {count} case(s). No agent evaluations ran.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
