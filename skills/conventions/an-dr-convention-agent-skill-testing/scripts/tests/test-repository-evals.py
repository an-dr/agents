"""Validate every checked-in evaluation suite."""

import importlib.util
import json
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "check-evals.py"
SPEC = importlib.util.spec_from_file_location("check_evals", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
ROOT = Path(__file__).resolve().parents[5]


if __name__ == "__main__":
    paths = sorted(ROOT.glob("skills/*/*/evals/evals.json"))
    assert paths, "No evaluation suites found"
    for path in paths:
        MODULE.validate(json.loads(path.read_text(encoding="utf-8-sig")), path.parent)
    print(f"Repository evaluation checks passed ({len(paths)} suites).")
