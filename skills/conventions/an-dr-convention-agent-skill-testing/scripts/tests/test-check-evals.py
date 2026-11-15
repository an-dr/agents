"""Exercise evaluation contract and archive rejection cases."""

import copy
import importlib.util
import io
import os
import tempfile
import zipfile
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "check-evals.py"
SPEC = importlib.util.spec_from_file_location("check_evals", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def suite():
    name = "example-skill"
    return {"schema_version": 1, "skill_name": name, "environment": {"host": "current", "model": "current", "os": ["windows", "linux", "macos"], "tools": ["git"], "network": "disabled", "permissions": "workspace-only", "discovery": "host-native", "instructions": ["target-and-dependencies"], "workspace": "fresh-git"}, "evals": [{"id": bucket, "bucket": bucket, "prompt": f"Use {name} to summarize this log." if bucket == "explicit" else "Summarize this log.", "expected_skill": None if bucket == "negative" else name, "expected_behavior": ["Preserves facts."], "assertions": [{"type": "diff_scope", "allowed_paths": []}], "runs": 5} for bucket in MODULE.BUCKETS]}


def reject(value, expected, root=None):
    try:
        MODULE.validate(value, root)
    except (ValueError, OSError, UnicodeError) as error:
        assert expected in str(error), f"expected {expected!r}, got {error!r}"
    else:
        raise AssertionError(f"Expected rejection: {expected}")


def main():
    assert MODULE.validate(suite(), None) == 4
    value = suite()
    value["evals"][0]["follow_up"] = ["Now summarize the second log."]
    value["evals"][0]["environment"] = {"tools": ["git", "python"]}
    value["evals"][0]["assertions"] = [{"type": "invocation_check", "expected": True}, {"type": "transcript_check", "pattern": "git status"}, {"type": "file_check", "path": "out/report.md", "contains": "Summary"}, {"type": "exit_code", "command_pattern": "validate", "expected": 0}, {"type": "llm_judge", "rubric": "Preserves facts."}]
    assert MODULE.validate(value, None) == 4
    for field in ("schema_version", "skill_name", "environment", "evals"):
        value = suite(); del value[field]; reject(value, field)
    for field in MODULE.ENV_FIELDS:
        value = suite(); del value["environment"][field]; reject(value, field)
    for field in ("id", "bucket", "prompt", "expected_skill", "expected_behavior", "assertions", "runs"):
        value = suite(); del value["evals"][0][field]; reject(value, field)
    cases = [
        (lambda x: x.update(schema_version=2), "schema_version"),
        (lambda x: x["evals"][1].update(id="EXPLICIT"), "Duplicate case ID"),
        (lambda x: x.update(evals=x["evals"][:3]), "Missing bucket"),
        (lambda x: x["evals"][3].update(expected_skill="example-skill"), "must be null"),
        (lambda x: x["evals"][0].update(expected_skill=None), "must match"),
        (lambda x: x["evals"][1].update(prompt="Use example-skill"), "must not name"),
        (lambda x: x["evals"][0].update(prompt="Summarize."), "must name"),
        (lambda x: x["evals"][0].update(runs=0), "greater than zero"),
        (lambda x: x["evals"][0].update(runs="5"), "integer"),
        (lambda x: x["environment"].update(network="live"), "environment.network"),
        (lambda x: x["environment"].update(os=["unknown"]), "environment.os"),
        (lambda x: x.update(extra=1), "unknown field"),
        (lambda x: x["evals"][0].update(files={}), "unknown field"),
        (lambda x: x["evals"][0].update(assertions=[{"type": "unknown"}]), "Unknown assertion"),
        (lambda x: x["evals"][0].update(assertions=[{"type": "invocation_check", "expected": "true"}]), "boolean"),
        (lambda x: x["evals"][0].update(assertions=[{"type": "transcript_check", "pattern": "["}]), "Invalid regex"),
    ]
    for mutate, expected in cases:
        value = suite(); mutate(value); reject(value, expected)
    for path in ("../escape", "/absolute", "C:/drive", "a\\b", "a//b", ".git/config", "NUL.txt", "a./b"):
        value = suite(); value["evals"][0]["assertions"] = [{"type": "file_check", "path": path}]; reject(value, "unsafe path")
    with tempfile.TemporaryDirectory(prefix="skill-eval-validator-") as directory:
        root = Path(directory)
        (root / "fixtures").mkdir()
        value = suite(); value["evals"][0]["fixtures"] = ["fixtures/input.zip"]
        reject(value, "Missing suite file", root)
        archive_path = root / "fixtures/input.zip"
        def write_zip(names, mode=0):
            with zipfile.ZipFile(archive_path, "w") as output:
                for name in names:
                    info = zipfile.ZipInfo(name)
                    if mode:
                        info.external_attr = mode << 16
                    output.writestr(info, "input")
        for names in (["baseline/src/a.txt", "working/src/a.txt"], ["working/new.txt"], ["baseline/deleted.txt"]):
            write_zip(names); assert MODULE.validate(value, root) == 4
        names = ["baseline/../escape", "/absolute", "baseline/.git/config", "baseline/NUL.txt"]
        if os.sep != "\\":
            # zipfile rewrites backslashes to slashes on Windows before the validator can see them.
            names.append("baseline/a\\b")
        for name in names:
            write_zip([name]); reject(value, "unsafe path", root)
        write_zip(["other/a"]); reject(value, "outside baseline", root)
        write_zip(["baseline/a", "baseline/A"]); reject(value, "path collision", root)
        write_zip(["baseline/a", "baseline/a/b"]); reject(value, "file/directory collision", root)
        write_zip(["baseline/link"], 0xA000); reject(value, "ordinary file", root)
        value["evals"][0]["fixtures"] = ["fixtures/../input.zip"]; reject(value, "unsafe path", root)
        value = suite(); value["evals"][0]["assertions"] = [{"type": "deterministic", "script": "graders/missing.py"}]; reject(value, "Missing suite file", root)
    print("Evaluation validator regression checks passed.")


if __name__ == "__main__":
    main()
